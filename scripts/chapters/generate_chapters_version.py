#!/usr/bin/env python3
"""Generate a version.json for a chapters folder.

Chapters ship as a single bundled chapters.json rather than one file per episode,
so there's no per-file manifest to diff against. This writes a tiny companion file
the app can poll cheaply: if the hash matches what the client already has, it skips
downloading the (much larger) chapters.json entirely.

Also validates chapters.json before publishing — a malformed file that reaches the
server would leave every client unable to show chapters.

Usage:
    python generate_chapters_version.py /path/to/chapters/v1
"""

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

CHAPTERS_NAME = "chapters.json"
VERSION_NAME = "version.json"
CHUNK_SIZE = 8192


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(CHUNK_SIZE):
            h.update(chunk)
    return h.hexdigest()


def validate(path: Path) -> tuple[int, int]:
    """Returns (episodeCount, chapterCount), or exits with a message."""
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        sys.exit(f"Error: could not read {path}: {error}")

    episodes = document.get("episodes")
    if not isinstance(episodes, dict) or not episodes:
        sys.exit(f"Error: {path} has no 'episodes' object.")

    chapter_count = 0
    for episode_id, entry in episodes.items():
        chapters = entry.get("chapters") if isinstance(entry, dict) else None
        if not isinstance(chapters, list) or not chapters:
            sys.exit(f"Error: episode {episode_id} has no chapters.")
        for chapter in chapters:
            if not isinstance(chapter, dict):
                sys.exit(f"Error: episode {episode_id} has a malformed chapter entry.")
            if not isinstance(chapter.get("start"), int):
                sys.exit(f"Error: episode {episode_id} has a chapter with a non-integer 'start'.")
            if not str(chapter.get("title", "")).strip():
                sys.exit(f"Error: episode {episode_id} has a chapter with an empty 'title'.")
        chapter_count += len(chapters)

    return len(episodes), chapter_count


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a version.json describing the chapters.json in a folder.",
    )
    parser.add_argument("folder", type=Path, help="Folder containing chapters.json.")
    parser.add_argument(
        "--coverage-start",
        default="2026-01-01",
        help=(
            "Earliest episode publication date covered, YYYY-MM-DD. Shown in the "
            "app's Episódios settings. Widen it as older episodes are backfilled "
            "(default: 2026-01-01)."
        ),
    )
    args = parser.parse_args()

    try:
        datetime.strptime(args.coverage_start, "%Y-%m-%d")
    except ValueError:
        print("Error: --coverage-start must be YYYY-MM-DD.", file=sys.stderr)
        return 1

    folder: Path = args.folder.expanduser().resolve()
    if not folder.is_dir():
        print(f"Error: '{folder}' is not a directory or does not exist.", file=sys.stderr)
        return 1

    chapters_path = folder / CHAPTERS_NAME
    if not chapters_path.is_file():
        print(f"Error: '{chapters_path}' does not exist.", file=sys.stderr)
        return 1

    episode_count, chapter_count = validate(chapters_path)

    version = {
        "version": 1,
        "hash": sha256_of(chapters_path),
        "size": chapters_path.stat().st_size,
        "episodeCount": episode_count,
        "chapterCount": chapter_count,
        "coverageStart": args.coverage_start,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    output_path = folder / VERSION_NAME
    output_path.write_text(json.dumps(version, indent=2) + "\n", encoding="utf-8")

    print(
        f"Wrote {output_path}\n"
        f"  {episode_count} episode(s), {chapter_count} chapter(s), "
        f"{version['size'] / 1024:.0f} KB\n"
        f"  {version['hash'][:16]}…"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
