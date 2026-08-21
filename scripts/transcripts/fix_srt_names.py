#!/usr/bin/env python3
"""Fix misspelled people's names in .srt subtitle files."""

import argparse
import os
import shutil
import sys
from pathlib import Path


def parse_fix_pairs(fix_args: list[str]) -> dict[str, str]:
    replacements: dict[str, str] = {}
    for pair in fix_args:
        if "=" not in pair:
            print(f"Error: invalid --fix value '{pair}' (expected 'wrong=correct')", file=sys.stderr)
            sys.exit(1)
        parts = pair.split("=", maxsplit=1)
        wrong, correct = parts[0], parts[1]
        if not wrong or not correct:
            print(f"Error: empty side in --fix value '{pair}'", file=sys.stderr)
            sys.exit(1)
        replacements[wrong] = correct
    return replacements


def collect_srt_files(input_dir: Path, recursive: bool) -> list[Path]:
    if recursive:
        return sorted(input_dir.rglob("*.srt"))
    return sorted(input_dir.glob("*.srt"))


def read_file(path: Path) -> str | None:
    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            return path.read_text(encoding=encoding)
        except (UnicodeDecodeError, ValueError):
            continue
    return None


def apply_replacements(text: str, replacements: dict[str, str]) -> tuple[str, dict[str, int]]:
    counts: dict[str, int] = {}
    for wrong, correct in replacements.items():
        n = text.count(wrong)
        if n > 0:
            text = text.replace(wrong, correct)
            counts[wrong] = n
    return text, counts


def print_dry_run_diff(filepath: Path, original: str, corrected: str) -> None:
    orig_lines = original.splitlines()
    corr_lines = corrected.splitlines()
    print(f"\n--- {filepath}")
    for i, (ol, cl) in enumerate(zip(orig_lines, corr_lines), start=1):
        if ol != cl:
            print(f"  line {i}:")
            print(f"    - {ol}")
            print(f"    + {cl}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fix misspelled people's names in .srt subtitle files.",
    )
    parser.add_argument("input_dir", type=Path, help="Directory containing .srt files")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output directory for corrected files")
    parser.add_argument("--fix", action="append", required=True, metavar='"wrong=correct"',
                        help="Name replacement pair (repeatable)")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing files")
    parser.add_argument("-r", "--recursive", action="store_true", help="Search subdirectories for .srt files")
    args = parser.parse_args()

    input_dir: Path = args.input_dir.resolve()
    output_dir: Path = args.output.resolve()

    if not input_dir.is_dir():
        print(f"Error: input directory '{input_dir}' does not exist", file=sys.stderr)
        sys.exit(1)

    replacements = parse_fix_pairs(args.fix)
    srt_files = collect_srt_files(input_dir, args.recursive)

    if not srt_files:
        print("No .srt files found.")
        return

    if not args.dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)

    total_files = len(srt_files)
    files_changed = 0
    total_counts: dict[str, int] = {wrong: 0 for wrong in replacements}

    for srt_path in srt_files:
        rel_path = srt_path.relative_to(input_dir)
        text = read_file(srt_path)
        if text is None:
            print(f"Warning: could not decode '{rel_path}', skipping", file=sys.stderr)
            continue

        corrected, counts = apply_replacements(text, replacements)
        changed = bool(counts)

        if changed:
            files_changed += 1
            for wrong, n in counts.items():
                total_counts[wrong] += n

        if args.dry_run:
            if changed:
                print_dry_run_diff(rel_path, text, corrected)
        else:
            dest = output_dir / rel_path
            dest.parent.mkdir(parents=True, exist_ok=True)
            if changed:
                dest.write_text(corrected, encoding="utf-8")
            else:
                shutil.copy2(srt_path, dest)

    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}Summary:")
    print(f"  Files scanned : {total_files}")
    print(f"  Files changed : {files_changed}")
    if any(n > 0 for n in total_counts.values()):
        print("  Replacements  :")
        for wrong, n in total_counts.items():
            if n > 0:
                print(f"    '{wrong}' -> '{replacements[wrong]}' : {n}")
    if not args.dry_run and files_changed > 0:
        print(f"  Output written to: {output_dir}")


if __name__ == "__main__":
    main()
