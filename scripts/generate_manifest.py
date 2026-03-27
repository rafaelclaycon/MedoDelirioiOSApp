#!/usr/bin/env python3
"""Generate a manifest.json for all files in a folder.

Each entry contains the episodeId (filename stem), a SHA-256 hash of the file
contents, and the file size in bytes.

Usage:
    python generate_manifest.py /path/to/folder
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

MANIFEST_NAME = "manifest.json"
IGNORED_FILES = {MANIFEST_NAME, ".DS_Store"}
CHUNK_SIZE = 8192


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(CHUNK_SIZE):
            h.update(chunk)
    return h.hexdigest()


def build_manifest(folder: Path) -> dict:
    entries = []
    for entry in sorted(folder.iterdir()):
        if not entry.is_file() or entry.name in IGNORED_FILES:
            continue
        entries.append({
            "episodeId": entry.stem,
            "hash": sha256_of(entry),
            "size": entry.stat().st_size,
        })

    entries.sort(key=lambda e: e["episodeId"])
    return {"version": 1, "files": entries}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a manifest.json with episodeId, SHA-256 hash, and size for every file in a folder.",
    )
    parser.add_argument("folder", type=Path, help="Path to the folder containing the files.")
    args = parser.parse_args()

    folder: Path = args.folder.expanduser().resolve()
    if not folder.is_dir():
        print(f"Error: '{folder}' is not a directory or does not exist.", file=sys.stderr)
        return 1

    manifest = build_manifest(folder)
    output_path = folder / MANIFEST_NAME
    output_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {len(manifest['files'])} entries to {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
