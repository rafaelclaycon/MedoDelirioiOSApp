#!/usr/bin/env python3
"""Suggest new Reactions from the sound catalog using the Claude API.

A Reaction is a themed micro-playlist of meme sounds (e.g. "Vergonha Alheia")
that users share to react to a situation. This is a one-off, run-by-hand tool:
it reads the JSON exported from the app's Dev Options screen, asks the model
to propose new groupings, and writes candidates for human review — nothing
here publishes anything automatically.

Usage:
    export ANTHROPIC_API_KEY='...'
    ./generate_reactions.py reactions_export.json suggestions.json
    ./generate_reactions.py reactions_export.json suggestions.json --dry-run
    ./generate_reactions.py reactions_export.json suggestions.json --count 15
"""

import argparse
import json
import os
import sys
from pathlib import Path

# Claude Opus 5 is the default, same as the chapters pipeline. Switching to
# "claude-sonnet-5" is a one-line change and roughly 40% the cost.
MODEL = "claude-opus-5"

INSTRUCTIONS = """\
Você recebe o catálogo de sons do app Medo e Delírio, um app de sons e memes \
brasileiros, e uma lista de "Reactions" já existentes. Uma Reaction é uma \
pequena coleção temática de sons (tipicamente 3 a 8) que o usuário compartilha \
para reagir a uma situação — ex: "Vergonha Alheia", "Quando o Chefe Chama".

Sua tarefa é sugerir NOVAS Reactions a partir do catálogo de sons fornecido.

Regras:
- Cada Reaction sugerida deve ter um tema claro e específico — a razão de um \
som estar ali deve ser óbvia para quem conhece os sons.
- O tamanho varia com o tema, como nos exemplos reais (de poucos sons a \
dezenas). Inclua todo som do catálogo que se encaixa claramente no tema, mas \
não force sons que não encaixam só para aumentar a lista.
- Use apenas IDs de som que existem no catálogo fornecido.
- Não repita nem parafraseie os títulos das Reactions já existentes — proponha \
temas realmente novos.
- Títulos curtos (no máximo 5 palavras), no mesmo tom e formato dos exemplos \
reais fornecidos.
- Um mesmo som pode aparecer em mais de uma Reaction sugerida, mas evite que \
um único som domine todas as sugestões.
"""


def build_prompt(export: dict, count: int) -> str:
    sounds_lines = "\n".join(
        f"{s['id']}\t{s['title']}\t{s['authorName']}" for s in export["sounds"]
    )

    examples_lines = "\n\n".join(
        f"\"{r['title']}\": " + ", ".join(r["soundTitles"])
        for r in export.get("sampleReactions", [])
    )

    existing_titles = ", ".join(f'"{t}"' for t in export["existingReactionTitles"])

    return f"""\
## Reactions já existentes (não repita nem parafraseie estes temas)

{existing_titles}

## Exemplos reais de Reactions (para calibrar tom, tamanho e formato)

{examples_lines}

## Catálogo de sons (id, título, autor)

{sounds_lines}

## Tarefa

Proponha {count} novas Reactions a partir do catálogo acima.
"""


EXIT_OUT_OF_CREDIT = 2

CREDIT_HINTS = ("credit balance", "credit_balance", "billing")


def is_credit_error(error: object) -> bool:
    text = f"{getattr(error, 'message', '') or ''} {error}".lower()
    return any(hint in text for hint in CREDIT_HINTS)


def request_reactions(prompt: str, model: str) -> list[dict]:
    """Returns [{"title": str, "sound_ids": [str]}]. Imports are local so
    --dry-run needs no deps."""
    import anthropic
    from pydantic import BaseModel, Field

    class ReactionSuggestion(BaseModel):
        title: str = Field(
            description="Título curto e concreto em português, no máximo 5 palavras."
        )
        sound_ids: list[str] = Field(
            description="IDs de som do catálogo fornecido que se encaixam no tema."
        )

    class ReactionSuggestionList(BaseModel):
        reactions: list[ReactionSuggestion]

    client = anthropic.Anthropic()
    try:
        response = client.messages.parse(
            model=model,
            max_tokens=16000,
            thinking={"type": "adaptive"},
            system=INSTRUCTIONS,
            messages=[{"role": "user", "content": prompt}],
            output_format=ReactionSuggestionList,
        )
    except anthropic.APIStatusError as error:
        if is_credit_error(error):
            print(
                "Out of API credits. Top up at https://platform.claude.com.",
                file=sys.stderr,
            )
            raise SystemExit(EXIT_OUT_OF_CREDIT)
        raise SystemExit(f"API request failed: {error}")

    if response.stop_reason == "refusal":
        raise SystemExit(f"request refused: {response.stop_details}")
    if response.stop_reason == "max_tokens":
        raise SystemExit("hit max_tokens — output truncated; raise max_tokens")
    if response.parsed_output is None:
        raise SystemExit("model returned no parseable output")

    print(
        f"  tokens: {response.usage.input_tokens} in, "
        f"{response.usage.output_tokens} out",
        file=sys.stderr,
    )
    return [
        {"title": r.title, "sound_ids": r.sound_ids}
        for r in response.parsed_output.reactions
    ]


def resolve(parsed: list[dict], export: dict) -> tuple[list[dict], list[str]]:
    """Drops suggestions with unknown sound ids or out-of-range size, and
    attaches sound titles/authors for the review viewer."""
    sounds_by_id = {s["id"]: s for s in export["sounds"]}
    existing_titles = {t.strip().lower() for t in export["existingReactionTitles"]}

    resolved: list[dict] = []
    problems: list[str] = []
    for suggestion in parsed:
        title = suggestion["title"].strip()
        if not title:
            problems.append("(sem título) — descartada")
            continue
        if title.strip().lower() in existing_titles:
            problems.append(f"{title!r}: duplica uma Reaction existente — descartada")
            continue

        sounds = []
        unknown_ids = []
        for sound_id in suggestion["sound_ids"]:
            sound = sounds_by_id.get(sound_id)
            if sound is None:
                unknown_ids.append(sound_id)
            else:
                sounds.append(sound)
        if unknown_ids:
            problems.append(
                f"{title!r}: {len(unknown_ids)} id(s) desconhecido(s) — removidos"
            )
        if len(sounds) < 3:
            problems.append(
                f"{title!r}: só {len(sounds)} som(ns) após limpeza — descartada"
            )
            continue

        resolved.append({"title": title, "sounds": sounds})

    return resolved, problems


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("export", type=Path, help="reactions_export.json from the app")
    parser.add_argument("target", type=Path, help="where to write suggestions.json")
    parser.add_argument("--model", default=MODEL)
    parser.add_argument("--count", type=int, default=10, help="how many Reactions to request")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Build the prompt and report its size without calling the API",
    )
    args = parser.parse_args()

    export = json.loads(args.export.read_text(encoding="utf-8"))
    prompt = build_prompt(export, args.count)
    print(
        f"{args.export.name}: {len(export['sounds'])} sounds, "
        f"{len(export['existingReactionTitles'])} existing Reactions, "
        f"{len(prompt):,} chars, ~{len(prompt.split()):,} words",
        file=sys.stderr,
    )

    if args.dry_run:
        print("--dry-run: stopping before the API call", file=sys.stderr)
        return

    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise SystemExit("ANTHROPIC_API_KEY is not set")

    parsed = request_reactions(prompt, args.model)
    reactions, problems = resolve(parsed, export)

    if problems:
        print(f"{len(problems)} problem(s):", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
    if not reactions:
        raise SystemExit("no usable suggestions — nothing written")

    args.target.write_text(
        json.dumps({"reactions": reactions}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\n{len(reactions)} suggestion(s) written to {args.target}")
    for reaction in reactions:
        titles = ", ".join(s["title"] for s in reaction["sounds"])
        print(f"  {reaction['title']}: {titles}")


if __name__ == "__main__":
    main()
