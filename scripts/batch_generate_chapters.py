#!/usr/bin/env python3
"""Generate episode chapters in bulk via the Claude Message Batches API.

Batches run asynchronously (usually under an hour, up to 24) at 50% of standard
token prices, so this is split into two phases:

    submit  build the requests, send the batch, write a state file
    fetch   poll the batch, resolve results, merge into chapters.json

Episodes already present in chapters.json are skipped and left untouched, so
re-running after adding episodes only processes what's new.

Usage:
    export ANTHROPIC_API_KEY='...'

    # See what would run, with a cost estimate — no API calls, no spend
    ./batch_generate_chapters.py submit --last 50 --dry-run

    # Submit
    ./batch_generate_chapters.py submit --last 50

    # Later — poll and merge
    ./batch_generate_chapters.py fetch

Filters combine as an intersection: `--since 2026-01-01 --last 20` means the 20
most recent episodes published on or after that date.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

MODEL = "claude-opus-5"
API_BASE = "https://api.medodelirioios.com/"
SPREAKER_SHOW = "4711842"

CUE_TIME = re.compile(r"(\d+):(\d+):(\d+)[,.](\d+)\s*-->")

# The Batches API caps a request payload at 256 MB. Stay well under it and tell
# the user to split rather than discovering the limit at submit time.
MAX_BATCH_BYTES = 200 * 1024 * 1024

# Calibrated on one measured Opus 5 run: 106,849 chars ≈ 27K input tokens,
# ~5K output tokens. Used only for the --dry-run estimate.
CHARS_PER_TOKEN = 3.9
OUTPUT_TOKENS_PER_EPISODE = 5000
PRICE_IN_PER_MTOK = 5.0
PRICE_OUT_PER_MTOK = 25.0
BATCH_DISCOUNT = 0.5

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

CHAPTER_SCHEMA = {
    "type": "object",
    "properties": {
        "chapters": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "start_cue": {
                        "type": "integer",
                        "description": "Número da fala em que o capítulo começa.",
                    },
                    "title": {
                        "type": "string",
                        "description": "Título curto e concreto em português.",
                    },
                },
                "required": ["start_cue", "title"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["chapters"],
    "additionalProperties": False,
}


# MARK: - Credit exhaustion

# Running out of credits comes back as HTTP 400 `invalid_request_error` whose
# message names the credit balance. A 400 is not in the SDK's auto-retry set, so
# it surfaces immediately rather than after a backoff — there is nothing to wait
# out, and the only fix is topping up.
CREDIT_HINTS = ("credit balance", "credit_balance", "billing")

TOP_UP_MESSAGE = (
    "Out of API credits. Top up at https://platform.claude.com and re-run — "
    "episodes already written to chapters.json are skipped automatically."
)


def is_credit_error(error: object) -> bool:
    """True when a failure looks like exhausted credits rather than a bug."""
    text = f"{getattr(error, 'message', '') or ''} {error}".lower()
    return any(hint in text for hint in CREDIT_HINTS)


# MARK: - Episode discovery


def fetch_json(url: str) -> dict:
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read())


def transcript_episode_ids() -> set[str]:
    """Only episodes with a published transcript can be chaptered."""
    manifest = fetch_json(API_BASE + "transcripts/v1/manifest.json")
    return {entry["episodeId"] for entry in manifest["files"]}


def spreaker_episodes() -> list[tuple[str, str, str]]:
    """Every episode as (id, published_at, title), newest first."""
    episodes: list[tuple[str, str, str]] = []
    url = f"https://api.spreaker.com/v2/shows/{SPREAKER_SHOW}/episodes?limit=100"

    while url:
        payload = fetch_json(url).get("response", {})
        for item in payload.get("items", []):
            episodes.append(
                (
                    str(item["episode_id"]),
                    item.get("published_at", ""),
                    item.get("title", ""),
                )
            )
        url = payload.get("next_url")

    episodes.sort(key=lambda entry: entry[1], reverse=True)
    return episodes


def select_episodes(since: str | None, last: int | None) -> list[tuple[str, str, str]]:
    have_transcript = transcript_episode_ids()
    episodes = [e for e in spreaker_episodes() if e[0] in have_transcript]

    if since:
        episodes = [e for e in episodes if e[1][:10] >= since]
    if last:
        episodes = episodes[:last]

    return episodes


# MARK: - Transcript handling


def local_srt(episode_id: str, srt_dir: Path) -> Path:
    """Returns the SRT path, downloading into `srt_dir` when not already cached."""
    srt_dir.mkdir(parents=True, exist_ok=True)
    path = srt_dir / f"{episode_id}.srt"

    if not path.exists():
        url = API_BASE + f"transcripts/v1/{episode_id}.srt"
        with urllib.request.urlopen(url) as response:
            path.write_bytes(response.read())

    return path


def parse_srt(path: Path) -> list[tuple[int, int, str]]:
    """Returns [(cue_number, start_seconds, text)], renumbered from 1.

    The file's own indices are ignored — they're sometimes duplicated or out of
    order, and the numbering the model sees has to match what we resolve against.
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

    return cues


def build_prompt(cues: list[tuple[int, int, str]]) -> str:
    return "\n".join(f"{number} {text}" for number, _, text in cues)


# MARK: - chapters.json


def load_chapters(target: Path) -> dict:
    if target.exists():
        return json.loads(target.read_text(encoding="utf-8"))
    return {"version": 1, "episodes": {}}


def already_done(document: dict, episode_id: str) -> bool:
    return episode_id in document.get("episodes", {})


def is_manual(document: dict, episode_id: str) -> bool:
    entry = document.get("episodes", {}).get(episode_id)
    return isinstance(entry, dict) and entry.get("source") == "manual"


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
            problems.append(f"cue {start_cue} not in transcript (1-{len(cues)})")
            continue
        resolved.append({"start": starts[start_cue], "title": title})

    resolved.sort(key=lambda chapter: chapter["start"])

    deduped, seen = [], set()
    for chapter in resolved:
        if chapter["start"] not in seen:
            seen.add(chapter["start"])
            deduped.append(chapter)

    return deduped, problems


# MARK: - Submit


def submit(args: argparse.Namespace) -> None:
    target = args.chapters
    document = load_chapters(target)

    episodes = select_episodes(args.since, args.last)
    if not episodes:
        raise SystemExit("no episodes matched the filters")

    pending = []
    skipped = 0
    for episode_id, published, title in episodes:
        if already_done(document, episode_id) and not args.force:
            skipped += 1
            continue
        if is_manual(document, episode_id):
            skipped += 1
            continue
        pending.append((episode_id, published, title))

    print(f"{len(episodes)} episode(s) matched, {skipped} already done, {len(pending)} to generate")
    if not pending:
        return

    requests_payload = []
    total_chars = 0
    for episode_id, published, title in pending:
        cues = parse_srt(local_srt(episode_id, args.srt_dir))
        if not cues:
            print(f"  skipping {episode_id}: no cues parsed", file=sys.stderr)
            continue
        prompt = build_prompt(cues)
        total_chars += len(prompt)
        requests_payload.append(
            {
                "custom_id": episode_id,
                "params": {
                    "model": args.model,
                    "max_tokens": 16000,
                    "system": INSTRUCTIONS,
                    "messages": [{"role": "user", "content": prompt}],
                    "output_config": {
                        "format": {"type": "json_schema", "schema": CHAPTER_SCHEMA}
                    },
                },
            }
        )
        print(f"  {episode_id}  {published[:10]}  {len(cues):>5} cues  {title[:48]}")

    if not requests_payload:
        raise SystemExit("nothing to submit")

    input_tokens = total_chars / CHARS_PER_TOKEN
    output_tokens = OUTPUT_TOKENS_PER_EPISODE * len(requests_payload)
    cost = (
        input_tokens / 1e6 * PRICE_IN_PER_MTOK + output_tokens / 1e6 * PRICE_OUT_PER_MTOK
    ) * BATCH_DISCOUNT

    payload_bytes = len(json.dumps(requests_payload).encode())
    print(
        f"\n{len(requests_payload)} request(s), {payload_bytes / 1024 / 1024:.1f} MB payload\n"
        f"~{input_tokens / 1e6:.1f}M input tokens, estimated ${cost:.2f} on {args.model} (batch rate)"
    )

    if payload_bytes > MAX_BATCH_BYTES:
        raise SystemExit(
            f"payload is {payload_bytes / 1024 / 1024:.0f} MB, over the safe limit — "
            "split the run with --last or --since"
        )

    if args.dry_run:
        print("--dry-run: stopping before submitting")
        return

    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise SystemExit("ANTHROPIC_API_KEY is not set")

    import anthropic

    client = anthropic.Anthropic()

    try:
        batch = client.messages.batches.create(requests=requests_payload)
    except anthropic.APIStatusError as error:
        # No state file is written, so nothing half-submitted is recorded.
        raise SystemExit(TOP_UP_MESSAGE if is_credit_error(error) else f"submit failed: {error}")

    args.state.write_text(
        json.dumps(
            {
                "batch_id": batch.id,
                "model": args.model,
                "submitted_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "episode_ids": [r["custom_id"] for r in requests_payload],
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    print(f"\nbatch {batch.id} submitted ({batch.processing_status})")
    print(f"state written to {args.state}")
    print(f"run: {sys.argv[0]} fetch")


# MARK: - Fetch


def fetch(args: argparse.Namespace) -> None:
    if not args.state.exists():
        raise SystemExit(f"{args.state} not found — run submit first")

    state = json.loads(args.state.read_text(encoding="utf-8"))
    batch_id = state["batch_id"]

    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise SystemExit("ANTHROPIC_API_KEY is not set")

    import anthropic

    client = anthropic.Anthropic()

    while True:
        try:
            batch = client.messages.batches.retrieve(batch_id)
        except anthropic.APIStatusError as error:
            raise SystemExit(
                TOP_UP_MESSAGE if is_credit_error(error) else f"could not read batch: {error}"
            )

        if batch.processing_status == "ended":
            break
        counts = batch.request_counts
        print(
            f"{batch.processing_status}: {counts.succeeded} done, "
            f"{counts.processing} processing, {counts.errored} errored",
            file=sys.stderr,
        )
        if args.no_wait:
            raise SystemExit("batch not finished yet (--no-wait)")
        time.sleep(args.poll_interval)

    target = args.chapters
    document = load_chapters(target)
    document.setdefault("episodes", {})

    written = 0
    failures: list[str] = []
    out_of_credit = False
    interrupted: str | None = None

    # Credits can run out midway through a batch, so every exit path below falls
    # through to the write — whatever resolved is kept, and `submit` skips those
    # episodes on the retry.
    try:
        # Results come back in arbitrary order — key by custom_id, never by position.
        for result in client.messages.batches.results(batch_id):
            episode_id = result.custom_id

            if result.result.type != "succeeded":
                error = getattr(result.result, "error", None)
                if error is not None and is_credit_error(error):
                    out_of_credit = True
                    failures.append(f"{episode_id}: out of credit")
                else:
                    failures.append(f"{episode_id}: {result.result.type}")
                continue

            message = result.result.message
            if message.stop_reason == "refusal":
                failures.append(f"{episode_id}: refused")
                continue
            if message.stop_reason == "max_tokens":
                failures.append(f"{episode_id}: truncated (max_tokens)")
                continue

            text = next((b.text for b in message.content if b.type == "text"), None)
            if not text:
                failures.append(f"{episode_id}: no text block in response")
                continue

            try:
                payload = json.loads(text)
                parsed = [(c["start_cue"], c["title"]) for c in payload["chapters"]]
            except (json.JSONDecodeError, KeyError, TypeError) as error:
                failures.append(f"{episode_id}: unparseable output ({error})")
                continue

            cues = parse_srt(local_srt(episode_id, args.srt_dir))
            chapters, problems = resolve(parsed, cues)
            if not chapters:
                failures.append(f"{episode_id}: no chapters resolved")
                continue
            for problem in problems:
                print(f"  {episode_id}: {problem}", file=sys.stderr)

            if is_manual(document, episode_id):
                failures.append(f"{episode_id}: marked manual, left untouched")
                continue

            document["episodes"][episode_id] = {
                "source": "api",
                "modelVersion": state["model"],
                "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "chapters": chapters,
            }
            written += 1
            print(f"  {episode_id}: {len(chapters)} chapters")
    except anthropic.APIStatusError as error:
        out_of_credit = is_credit_error(error)
        interrupted = str(error)
    except KeyboardInterrupt:
        interrupted = "interrupted"

    target.write_text(
        json.dumps(document, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(f"\n{written} episode(s) written to {target} ({len(document['episodes'])} total)")

    if failures:
        print(f"{len(failures)} failure(s):")
        for failure in failures:
            print(f"  {failure}")

    if out_of_credit:
        print(f"\n{TOP_UP_MESSAGE}")
        raise SystemExit(1)
    if interrupted:
        print(f"\nStopped early: {interrupted}")
        print("Results above are saved; re-run fetch to pick up the rest.")
        raise SystemExit(1)
    if failures:
        print("Re-run submit to retry them — episodes already written are skipped.")


# MARK: - CLI


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)

    def shared(p: argparse.ArgumentParser) -> None:
        p.add_argument("--chapters", type=Path, default=Path("chapters.json"))
        p.add_argument(
            "--srt-dir",
            type=Path,
            default=Path("srt-cache"),
            help="Where SRTs are cached; missing ones are downloaded (default: srt-cache)",
        )
        p.add_argument("--state", type=Path, default=Path("batch-state.json"))

    submit_parser = sub.add_parser("submit", help="Build and send a batch")
    shared(submit_parser)
    submit_parser.add_argument("--since", help="Only episodes published on/after YYYY-MM-DD")
    submit_parser.add_argument("--last", type=int, help="Only the N most recent episodes")
    submit_parser.add_argument("--model", default=MODEL)
    submit_parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate episodes already in chapters.json (never overrides source=manual)",
    )
    submit_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List what would run and estimate cost without calling the API",
    )

    fetch_parser = sub.add_parser("fetch", help="Poll a submitted batch and merge results")
    shared(fetch_parser)
    fetch_parser.add_argument("--poll-interval", type=int, default=60)
    fetch_parser.add_argument(
        "--no-wait", action="store_true", help="Exit instead of polling if unfinished"
    )

    args = parser.parse_args()
    (submit if args.command == "submit" else fetch)(args)


if __name__ == "__main__":
    main()
