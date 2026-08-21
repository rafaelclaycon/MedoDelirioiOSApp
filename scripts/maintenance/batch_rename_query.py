#!/usr/bin/env python3
"""Batch rename files by stripping the '?p=' prefix from filenames.

Usage:
    python batch_rename_query.py /path/to/folder          # dry-run (preview only)
    python batch_rename_query.py /path/to/folder --apply   # perform renames
"""

import argparse
import sys
from pathlib import Path

MARKER = "?p="


def compute_new_name(path: Path) -> Path | None:
    """Return the new path if the filename contains '?p=', else None."""
    name = path.name
    idx = name.find(MARKER)
    if idx == -1:
        return None
    new_name = name[:idx] + name[idx + len(MARKER):]
    if not new_name:
        return None
    return path.with_name(new_name)


def collect_renames(folder: Path) -> tuple[list[tuple[Path, Path]], list[Path], list[tuple[Path, Path]]]:
    """Walk *folder* (non-recursive) and build rename plan.

    Returns (renames, skipped_no_match, skipped_collision).
    """
    renames: list[tuple[Path, Path]] = []
    skipped_no_match: list[Path] = []
    skipped_collision: list[tuple[Path, Path]] = []
    seen_targets: dict[Path, Path] = {}

    for entry in sorted(folder.iterdir()):
        if not entry.is_file():
            continue

        new_path = compute_new_name(entry)
        if new_path is None:
            skipped_no_match.append(entry)
            continue

        if new_path in seen_targets or (new_path.exists() and new_path not in {e for e, _ in renames}):
            skipped_collision.append((entry, new_path))
            continue

        seen_targets[new_path] = entry
        renames.append((entry, new_path))

    return renames, skipped_no_match, skipped_collision


def print_plan(
    renames: list[tuple[Path, Path]],
    skipped_no_match: list[Path],
    skipped_collision: list[tuple[Path, Path]],
    apply: bool,
) -> None:
    mode = "APPLYING" if apply else "DRY-RUN"
    print(f"\n[{mode}]\n")

    if renames:
        max_old = max(len(old.name) for old, _ in renames)
        for old, new in renames:
            print(f"  {old.name:<{max_old}}  ->  {new.name}")
    else:
        print("  (no files to rename)")

    if skipped_no_match:
        print(f"\nSkipped (no '?p='): {len(skipped_no_match)} file(s)")

    if skipped_collision:
        print("\nSkipped (collision):")
        for old, new in skipped_collision:
            print(f"  {old.name}  ->  {new.name}  (target already claimed)")

    print(f"\nSummary: {len(renames)} rename(s), "
          f"{len(skipped_no_match)} skipped (no match), "
          f"{len(skipped_collision)} skipped (collision)")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Batch rename files by removing '?p=' from filenames.",
    )
    parser.add_argument("folder", type=Path, help="Path to the folder containing files to rename.")
    parser.add_argument("--apply", action="store_true", help="Actually rename files. Without this flag the script only previews changes.")
    args = parser.parse_args()

    folder: Path = args.folder.expanduser().resolve()
    if not folder.is_dir():
        print(f"Error: '{folder}' is not a directory or does not exist.", file=sys.stderr)
        return 1

    renames, skipped_no_match, skipped_collision = collect_renames(folder)
    print_plan(renames, skipped_no_match, skipped_collision, apply=args.apply)

    if args.apply:
        for old, new in renames:
            old.rename(new)
        print("\nDone.")

    if not args.apply and renames:
        print("\nRun again with --apply to execute the renames.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
