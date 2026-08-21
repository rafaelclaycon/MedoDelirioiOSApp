#!/usr/bin/env python3
"""Batch rename files by stripping everything from the first '-' onward in the
filename stem while preserving the original extension.

Usage:
    python batch_rename.py /path/to/folder          # dry-run (preview only)
    python batch_rename.py /path/to/folder --apply   # perform renames
"""

import argparse
import sys
from pathlib import Path


def compute_new_name(path: Path) -> Path | None:
    """Return the new path if the stem contains a dash, else None."""
    stem = path.stem
    idx = stem.find("-")
    if idx == -1:
        return None
    new_stem = stem[:idx].rstrip()
    if not new_stem:
        return None
    return path.with_name(new_stem + path.suffix)


def collect_renames(folder: Path) -> tuple[list[tuple[Path, Path]], list[Path], list[tuple[Path, Path]]]:
    """Walk *folder* (non-recursive) and build rename plan.

    Returns (renames, skipped_no_dash, skipped_collision) where each rename
    is an (old, new) pair.
    """
    renames: list[tuple[Path, Path]] = []
    skipped_no_dash: list[Path] = []
    skipped_collision: list[tuple[Path, Path]] = []
    seen_targets: dict[Path, Path] = {}

    for entry in sorted(folder.iterdir()):
        if not entry.is_file():
            continue

        new_path = compute_new_name(entry)
        if new_path is None:
            skipped_no_dash.append(entry)
            continue

        if new_path in seen_targets or new_path.exists() and new_path not in {e for e, _ in renames}:
            skipped_collision.append((entry, new_path))
            continue

        seen_targets[new_path] = entry
        renames.append((entry, new_path))

    return renames, skipped_no_dash, skipped_collision


def print_plan(
    renames: list[tuple[Path, Path]],
    skipped_no_dash: list[Path],
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

    if skipped_no_dash:
        print(f"\nSkipped (no dash): {len(skipped_no_dash)} file(s)")

    if skipped_collision:
        print("\nSkipped (collision):")
        for old, new in skipped_collision:
            print(f"  {old.name}  ->  {new.name}  (target already claimed)")

    print(f"\nSummary: {len(renames)} rename(s), "
          f"{len(skipped_no_dash)} skipped (no dash), "
          f"{len(skipped_collision)} skipped (collision)")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Batch rename files by removing the first '-' and everything after it from the filename.",
    )
    parser.add_argument("folder", type=Path, help="Path to the folder containing files to rename.")
    parser.add_argument("--apply", action="store_true", help="Actually rename files. Without this flag the script only previews changes.")
    args = parser.parse_args()

    folder: Path = args.folder.expanduser().resolve()
    if not folder.is_dir():
        print(f"Error: '{folder}' is not a directory or does not exist.", file=sys.stderr)
        return 1

    renames, skipped_no_dash, skipped_collision = collect_renames(folder)
    print_plan(renames, skipped_no_dash, skipped_collision, apply=args.apply)

    if args.apply:
        for old, new in renames:
            old.rename(new)
        print("\nDone.")

    if not args.apply and renames:
        print("\nRun again with --apply to execute the renames.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
