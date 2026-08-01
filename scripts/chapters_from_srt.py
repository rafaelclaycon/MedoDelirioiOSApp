#!/usr/bin/env python3
"""Generate episode chapters from an SRT transcript using the Claude API.

Feeds the transcript as numbered cues and asks the model to return the *cue
number* each chapter starts at, rather than a timestamp. Three reasons:

  - Precision. Every cue has an exact start time, so a chapter can begin
    anywhere in the episode instead of on a coarse grid.
  - Robustness. A cue number is a small integer the model reads straight off
    the page — no timestamp arithmetic, and verification is just a dict lookup.
  - Cost. Dropping timestamp strings from the prompt saves roughly a third of
    the tokens versus feeding raw SRT.

Usage:
    export ANTHROPIC_API_KEY='...'
    ./chapters_from_srt.py 70769288.srt 70769288 chapters.json
    ./chapters_from_srt.py 70769288.srt 70769288 chapters.json --dry-run
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Claude Opus 5 is the default. Switching to "claude-sonnet-5" is a one-line
# change and roughly 40% the cost — worth trying first on a single episode.
MODEL = "claude-opus-5"

CUE_TIME = re.compile(r"(\d+):(\d+):(\d+)[,.](\d+)\s*-->")

INSTRUCTIONS = """\
Você recebe a transcrição de um episódio do podcast Medo e Delírio em Brasília, \
um podcast diário brasileiro sobre política. Cada linha começa com o número da \
fala, seguido do texto.

Divida o episódio em capítulos por assunto. Para cada capítulo, informe o número \
da fala em que o assunto começa (start_cue) e um título.

Regras:
- Um capítulo cobre UM assunto. Se o episódio passa muito tempo no mesmo tema, \
isso é um capítulo longo — não divida um assunto só porque ficou extenso.
- Marque o início real do assunto, não onde ele fica óbvio.
- O primeiro capítulo começa na fala 1.
- Títulos curtos e concretos (no máximo 6 palavras), descrevendo o assunto. \
Nunca use títulos genéricos como "Discussão", "Continuação" ou "Outros temas".
- Use apenas números de fala que existem na transcrição.
"""


def parse_srt(path: Path) -> list[tuple[int, int, str]]:
    """Returns [(cue_number, start_seconds, text)].

    Cues are renumbered sequentially from 1 rather than trusting the file's own
    indices, which are sometimes duplicated or out of order. The numbering the
    model sees is the numbering this function assigns.
    """
    content = path.read_text(encoding="utf-8").replace("\r\n", "\n")

    cues: list[tuple[int, int, str]] = []
    for block in content.split("\n\n"):
        lines = block.strip().split("\n")
        if len(lines) < 3:
            continue
        match = CUE_TIME.match(lines[1])
        if not match:
            continue
        hours, minutes, seconds, _ = map(int, match.groups())
        text = " ".join(lines[2:]).strip()
        if text:
            cues.append((len(cues) + 1, hours * 3600 + minutes * 60 + seconds, text))

    if not cues:
        raise SystemExit(f"{path}: no cues parsed — is that a valid SRT?")
    return cues


def build_prompt(cues: list[tuple[int, int, str]]) -> str:
    return "\n".join(f"{number} {text}" for number, _, text in cues)


# Distinct exit code so a caller — notably auto_transcribe.sh — can tell "out of
# credit, stop trying" apart from "this one episode failed, carry on".
EXIT_OUT_OF_CREDIT = 2

CREDIT_HINTS = ("credit balance", "credit_balance", "billing")


def is_credit_error(error: object) -> bool:
    text = f"{getattr(error, 'message', '') or ''} {error}".lower()
    return any(hint in text for hint in CREDIT_HINTS)


def request_chapters(prompt: str, model: str) -> list[tuple[int, str]]:
    """Returns [(start_cue, title)]. Imports are local so --dry-run needs no deps."""
    import anthropic
    from pydantic import BaseModel, Field

    class Chapter(BaseModel):
        start_cue: int = Field(
            description="Número da fala em que o capítulo começa."
        )
        title: str = Field(
            description="Título curto e concreto em português, no máximo 6 palavras."
        )

    class ChapterList(BaseModel):
        chapters: list[Chapter]

    client = anthropic.Anthropic()
    try:
        response = client.messages.parse(
            model=model,
            max_tokens=16000,
            thinking={"type": "adaptive"},
            system=INSTRUCTIONS,
            messages=[{"role": "user", "content": prompt}],
            output_format=ChapterList,
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
    return [(c.start_cue, c.title) for c in response.parsed_output.chapters]


def resolve(
    parsed: list[tuple[int, str]], cues: list[tuple[int, int, str]]
) -> tuple[list[dict], list[str]]:
    """Maps cue numbers to start times, dropping anything that doesn't resolve."""
    starts = {number: start for number, start, _ in cues}

    resolved: list[dict] = []
    problems: list[str] = []
    for start_cue, raw_title in parsed:
        title = raw_title.strip()
        if not title:
            continue
        if start_cue not in starts:
            problems.append(
                f"  {title!r}: cue {start_cue} is not in the transcript "
                f"(1-{len(cues)}) — dropped"
            )
            continue
        resolved.append({"start": starts[start_cue], "title": title})

    resolved.sort(key=lambda chapter: chapter["start"])

    deduped, seen = [], set()
    for chapter in resolved:
        if chapter["start"] not in seen:
            seen.add(chapter["start"])
            deduped.append(chapter)

    return deduped, problems


def merge_into(target: Path, episode_id: str, chapters: list[dict], model: str) -> int:
    if target.exists():
        document = json.loads(target.read_text(encoding="utf-8"))
    else:
        document = {"version": 1, "episodes": {}}

    existing = document["episodes"].get(episode_id)
    if existing and existing.get("source") == "manual":
        raise SystemExit(
            f"{episode_id} is marked manual — refusing to overwrite."
        )

    document["episodes"][episode_id] = {
        "source": "api",
        "modelVersion": model,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "chapters": chapters,
    }
    target.write_text(
        json.dumps(document, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return len(document["episodes"])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("srt", type=Path)
    parser.add_argument("episode_id")
    parser.add_argument("target", type=Path, help="chapters.json to create or update")
    parser.add_argument("--model", default=MODEL)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse the SRT and report prompt size without calling the API",
    )
    args = parser.parse_args()

    cues = parse_srt(args.srt)
    prompt = build_prompt(cues)
    print(
        f"{args.srt.name}: {len(cues)} cues, "
        f"{len(prompt):,} chars, ~{len(prompt.split()):,} words",
        file=sys.stderr,
    )

    if args.dry_run:
        print("--dry-run: stopping before the API call", file=sys.stderr)
        return

    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise SystemExit("ANTHROPIC_API_KEY is not set")

    parsed = request_chapters(prompt, args.model)
    chapters, problems = resolve(parsed, cues)

    if problems:
        print(f"{len(problems)} problem(s):", file=sys.stderr)
        for problem in problems:
            print(problem, file=sys.stderr)
    if not chapters:
        raise SystemExit("no usable chapters — nothing written")

    total = merge_into(args.target, args.episode_id, chapters, args.model)
    print(f"\n{args.episode_id} → {args.target} ({total} episode(s) total)")
    for chapter in chapters:
        print(f"  {chapter['start'] // 60:>3}m{chapter['start'] % 60:02d}s  {chapter['title']}")


if __name__ == "__main__":
    main()
