#!/usr/bin/env python3
"""Collect teamwork run logs into a central JSONL store with deduplication.

Usage:
    python3 collect-runs.py [--scan-dir ~/Development] [--store data/runs.jsonl]

Scans ~/Development/*/.claude/last-run-*.md, parses new runs, and appends
to the JSONL store. Existing run_ids are skipped (idempotent).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from parse_runs import scan_directory  # type: ignore  # noqa: E402

DEFAULT_STORE = Path(__file__).resolve().parent.parent / "data" / "runs.jsonl"


def load_existing_ids(store: Path) -> set:
    ids = set()
    if store.exists():
        for line in store.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    ids.add(json.loads(line)["run_id"])
                except (json.JSONDecodeError, KeyError):
                    pass
    return ids


def main():
    parser = argparse.ArgumentParser(description="Collect runs into central store")
    parser.add_argument("--scan-dir", default=str(Path.home() / "Development"))
    parser.add_argument("--store", default=str(DEFAULT_STORE))
    args = parser.parse_args()

    store = Path(args.store)
    store.parent.mkdir(parents=True, exist_ok=True)

    existing = load_existing_ids(store)
    runs = scan_directory(Path(args.scan_dir))

    new_count = 0
    with open(store, "a", encoding="utf-8") as f:
        for run in runs:
            if run["run_id"] not in existing:
                json.dump(run, f, ensure_ascii=False)
                f.write("\n")
                existing.add(run["run_id"])
                new_count += 1

    total = len(existing)
    print(f"Collected {new_count} new runs (total: {total}) → {store}")


if __name__ == "__main__":
    main()
