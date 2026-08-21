#!/usr/bin/env python3
"""Scan SRT transcript files for repeating lines caused by LLM transcription loops.

Detects two patterns:
  1. Consecutive exact duplicates – the same cue text in adjacent cues.
  2. Short repeating cycles   – e.g. A-B-A-B-A-B (cycle length 2-5, repeated 3+ times).

Usage:
    python check_srt_repeats.py PATH [PATH ...]

Each PATH can be an .srt file or a directory (scanned recursively).
Exit code 0 = clean, 1 = issues found.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import List, Optional, Sequence


# ---------------------------------------------------------------------------
# SRT parsing
# ---------------------------------------------------------------------------

@dataclass
class SRTCue:
    index: int
    start_time: float
    end_time: float
    text: str


_TIMESTAMP_RE = re.compile(
    r"(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})"
)


def _parse_timestamp(raw: str) -> Optional[float]:
    m = _TIMESTAMP_RE.match(raw.strip())
    if not m:
        return None
    h, mn, s, ms = (int(g) for g in m.groups())
    return h * 3600 + mn * 60 + s + ms / 1000


def parse_srt(content: str) -> List[SRTCue]:
    content = content.lstrip("\ufeff")
    content = content.replace("\r\n", "\n")
    blocks = re.split(r"\n{2,}", content.strip())
    cues: List[SRTCue] = []
    for block in blocks:
        lines = block.strip().split("\n")
        if len(lines) < 3:
            continue
        try:
            index = int(lines[0].strip())
        except ValueError:
            continue
        time_parts = lines[1].split("-->")
        if len(time_parts) != 2:
            continue
        start = _parse_timestamp(time_parts[0])
        end = _parse_timestamp(time_parts[1])
        if start is None or end is None:
            continue
        text = "\n".join(lines[2:]).strip()
        if not text:
            continue
        cues.append(SRTCue(index=index, start_time=start, end_time=end, text=text))
    cues.sort(key=lambda c: c.start_time)
    return cues


# ---------------------------------------------------------------------------
# Detection issues
# ---------------------------------------------------------------------------

@dataclass
class ConsecutiveDuplicate:
    kind: str = field(default="CONSECUTIVE DUPLICATE", init=False)
    cue_start: int
    cue_end: int
    count: int
    text: str


@dataclass
class RepeatingCycle:
    kind: str = field(default="REPEATING CYCLE", init=False)
    cue_start: int
    cue_end: int
    cycle_length: int
    repeat_count: int
    texts: List[str]


Issue = ConsecutiveDuplicate | RepeatingCycle


# ---------------------------------------------------------------------------
# Detection algorithms
# ---------------------------------------------------------------------------

def detect_consecutive_duplicates(
    cues: List[SRTCue],
    min_consecutive: int = 2,
) -> List[ConsecutiveDuplicate]:
    issues: List[ConsecutiveDuplicate] = []
    if not cues:
        return issues

    run_start = 0
    for i in range(1, len(cues) + 1):
        if i < len(cues) and cues[i].text == cues[run_start].text:
            continue
        run_len = i - run_start
        if run_len >= min_consecutive:
            issues.append(ConsecutiveDuplicate(
                cue_start=cues[run_start].index,
                cue_end=cues[i - 1].index,
                count=run_len,
                text=cues[run_start].text,
            ))
        run_start = i
    return issues


def detect_repeating_cycles(
    cues: List[SRTCue],
    min_cycle_repeats: int = 3,
    max_cycle_length: int = 5,
) -> List[RepeatingCycle]:
    """Find short repeating cycles (length 2-max_cycle_length) that repeat min_cycle_repeats+ times."""
    issues: List[RepeatingCycle] = []
    if not cues:
        return issues

    texts = [c.text for c in cues]
    n = len(texts)
    covered: set[int] = set()

    for cycle_len in range(2, max_cycle_length + 1):
        for start in range(n - cycle_len * min_cycle_repeats + 1):
            if start in covered:
                continue
            pattern = texts[start : start + cycle_len]
            repeats = 1
            pos = start + cycle_len
            while pos + cycle_len <= n and texts[pos : pos + cycle_len] == pattern:
                repeats += 1
                pos += cycle_len
            if repeats >= min_cycle_repeats:
                end_idx = start + repeats * cycle_len - 1
                already_covered = any(i in covered for i in range(start, end_idx + 1))
                if already_covered:
                    continue
                for i in range(start, end_idx + 1):
                    covered.add(i)
                issues.append(RepeatingCycle(
                    cue_start=cues[start].index,
                    cue_end=cues[end_idx].index,
                    cycle_length=cycle_len,
                    repeat_count=repeats,
                    texts=pattern,
                ))
    return issues


# ---------------------------------------------------------------------------
# File collection
# ---------------------------------------------------------------------------

def collect_srt_files(paths: Sequence[str]) -> List[Path]:
    files: List[Path] = []
    for raw in paths:
        p = Path(raw)
        if p.is_file() and p.suffix.lower() == ".srt":
            files.append(p)
        elif p.is_dir():
            files.extend(sorted(p.rglob("*.srt")))
        else:
            print(f"Warning: skipping {p} (not an .srt file or directory)", file=sys.stderr)
    return files


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def _truncate(text: str, max_len: int = 80) -> str:
    single = text.replace("\n", " ")
    if len(single) <= max_len:
        return single
    return single[: max_len - 1] + "…"


def report_plain(filepath: Path, issues: List[Issue]) -> None:
    print(f"\n=== {filepath} ===")
    for issue in issues:
        if isinstance(issue, ConsecutiveDuplicate):
            print(
                f"  [CONSECUTIVE DUPLICATE] Cues {issue.cue_start}-{issue.cue_end} "
                f"({issue.count}x): \"{_truncate(issue.text)}\""
            )
        elif isinstance(issue, RepeatingCycle):
            cycle_str = " / ".join(f"\"{_truncate(t, 40)}\"" for t in issue.texts)
            print(
                f"  [REPEATING CYCLE]       Cues {issue.cue_start}-{issue.cue_end} "
                f"(cycle of {issue.cycle_length}, {issue.repeat_count}x): {cycle_str}"
            )


def build_json_entry(filepath: Path, issues: List[Issue]) -> dict:
    return {
        "file": str(filepath),
        "issues": [asdict(i) for i in issues],
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def analyse_file(
    filepath: Path,
    *,
    min_consecutive: int,
    min_cycle_repeats: int,
) -> List[Issue]:
    content = filepath.read_text(encoding="utf-8-sig")
    cues = parse_srt(content)
    if not cues:
        return []

    issues: List[Issue] = []
    issues.extend(detect_consecutive_duplicates(cues, min_consecutive))
    issues.extend(detect_repeating_cycles(cues, min_cycle_repeats))
    return issues


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Detect repeating lines in SRT transcripts caused by LLM loops.",
    )
    parser.add_argument(
        "paths",
        nargs="+",
        metavar="PATH",
        help="SRT file or directory to scan (directories are searched recursively).",
    )
    parser.add_argument(
        "--min-consecutive",
        type=int,
        default=4,
        help="Minimum consecutive duplicate cues to flag (default: 4).",
    )
    parser.add_argument(
        "--min-cycle-repeats",
        type=int,
        default=3,
        help="Minimum times a cycle must repeat to be flagged (default: 3).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="output_json",
        help="Output results as JSON.",
    )
    args = parser.parse_args(argv)

    files = collect_srt_files(args.paths)
    if not files:
        print("No .srt files found.", file=sys.stderr)
        return 0

    found_issues = False
    json_results: List[dict] = []

    for filepath in files:
        try:
            issues = analyse_file(
                filepath,
                min_consecutive=args.min_consecutive,
                min_cycle_repeats=args.min_cycle_repeats,
            )
        except Exception as exc:
            print(f"Error reading {filepath}: {exc}", file=sys.stderr)
            continue

        if not issues:
            continue

        found_issues = True
        if args.output_json:
            json_results.append(build_json_entry(filepath, issues))
        else:
            report_plain(filepath, issues)

    if args.output_json:
        print(json.dumps(json_results, indent=2, ensure_ascii=False))
    elif not found_issues:
        print("All files clean — no repeating patterns detected.")

    return 1 if found_issues else 0


if __name__ == "__main__":
    sys.exit(main())
