#!/usr/bin/env python3
"""Parse teamwork last-run-*.md execution logs into structured JSON.

Usage:
    python3 parse-runs.py [--scan-dir ~/Development] [--output runs.jsonl]
    python3 parse-runs.py --file path/to/last-run-20260421-152950.md

Output: one JSON object per run with fields:
    run_id, timestamp, project, task, flow, outcome, agents[], tools[], skills[],
    stages[], missing_evidence[], stats{total_stages, completed, failed, interrupted}
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional


def parse_run_file(path: Path) -> Optional[Dict[str, Any]]:
    """Parse a single last-run-*.md file into a structured dict."""
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return None

    run: Dict[str, Any] = {
        "run_id": path.stem,  # last-run-YYYYMMDD-HHMMSS
        "source_file": str(path),
        "project": _detect_project(path),
    }

    # Extract timestamp from filename
    m = re.search(r"last-run-(\d{8})-(\d{6})", path.stem)
    if m:
        try:
            dt = datetime.strptime(f"{m.group(1)}{m.group(2)}", "%Y%m%d%H%M%S")
            run["timestamp"] = dt.isoformat()
        except ValueError:
            run["timestamp"] = None
    else:
        run["timestamp"] = None

    # Header fields
    run["task"] = _extract_field(text, r"\*\*Task:\*\*\s*(.+)")
    run["flow"] = _extract_field(text, r"\*\*Flow:\*\*\s*(.+)")
    run["outcome"] = _extract_field(text, r"\*\*Outcome:\*\*\s*(\w+)")

    # Flow sequence
    flow_section = _extract_section(text, "## Flow")
    run["flow_sequence"] = flow_section.strip() if flow_section else None

    # Tools & Skills
    tools_section = _extract_section(text, "## Tools Used")
    run["tools"] = _parse_csv_line(tools_section) if tools_section else []

    skills_section = _extract_section(text, "## Skills Used")
    run["skills"] = _parse_csv_line(skills_section) if skills_section else []

    # Roles / Agents
    roles_section = _extract_section(text, "## Roles / Agents / Models")
    run["agents"] = _parse_agents_section(roles_section) if roles_section else []

    # Execution Ledger (the main table)
    ledger_section = _extract_section(text, "## Execution Ledger")
    run["stages"] = _parse_ledger_table(ledger_section) if ledger_section else []

    # Missing Evidence Matrix
    missing_section = _extract_section(text, "## Missing Evidence Matrix")
    run["missing_evidence"] = _parse_missing_table(missing_section) if missing_section else []

    # Compute stats
    stages = run["stages"]
    statuses = [s.get("status", "unknown") for s in stages]
    run["stats"] = {
        "total_stages": len(stages),
        "completed": sum(1 for s in statuses if s in ("pass", "pass-with-nit")),
        "failed": sum(1 for s in statuses if s.startswith("fail")),
        "interrupted": sum(1 for s in statuses if s == "interrupted"),
        "skipped": sum(1 for s in statuses if s == "skipped"),
        "not_started": sum(1 for s in statuses if s in ("not_started", "unknown")),
        "iterate_count": sum(1 for s in statuses if "iterate" in s),
    }

    return run


def _detect_project(path: Path) -> str:
    """Detect project name from file path (parent of .claude/)."""
    for parent in path.parents:
        if parent.name == ".claude":
            return parent.parent.name
    return "unknown"


def _extract_field(text: str, pattern: str) -> Optional[str]:
    m = re.search(pattern, text)
    return m.group(1).strip() if m else None


def _extract_section(text: str, header: str) -> Optional[str]:
    """Extract text between a ## header and the next ## header."""
    pattern = re.escape(header) + r"\s*\n(.*?)(?=\n## |\Z)"
    m = re.search(pattern, text, re.DOTALL)
    return m.group(1).strip() if m else None


def _parse_csv_line(text: str) -> List[str]:
    """Parse comma/newline separated values, filtering 'none'."""
    items = re.split(r"[,\n]", text)
    result = [i.strip() for i in items if i.strip() and i.strip().lower() != "none"]
    return result


def _parse_agents_section(text: str) -> List[Dict[str, str]]:
    """Parse the Roles/Agents/Models section."""
    agents = []
    for line in text.strip().splitlines():
        line = line.strip().lstrip("- ")
        if not line:
            continue
        # Pattern: "Delegated worker: `role` (model) — note"
        m = re.match(r"Delegated worker:\s*`?(\S+?)`?\s*\(([^)]+)\)(?:\s*[—–-]\s*(.+))?", line)
        if m:
            agents.append({
                "role": m.group(1),
                "model": m.group(2),
                "note": m.group(3) or "",
            })
        else:
            agents.append({"role": line, "model": "unknown", "note": ""})
    return agents


def _parse_ledger_table(text: str) -> List[Dict[str, str]]:
    """Parse the execution ledger markdown table."""
    rows = []
    lines = text.strip().splitlines()
    headers = []
    for line in lines:
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")[1:-1]]  # skip empty first/last
        if not headers:
            headers = [h.lower().replace(" ", "_") for h in cells]
            continue
        if all(c.strip("-") == "" for c in cells):  # separator row
            continue
        row = {}
        for i, h in enumerate(headers):
            row[h] = cells[i] if i < len(cells) else ""
        # Normalize status
        status = row.get("status", "unknown").lower().strip()
        if "→" in status or "->" in status:
            # e.g. "iterate→pass" or "fail→pass"
            parts = re.split(r"→|->", status)
            row["status"] = parts[-1].strip()
            row["status_history"] = status
        else:
            row["status_history"] = status
        rows.append(row)
    return rows


def _parse_missing_table(text: str) -> List[Dict[str, str]]:
    """Parse the missing evidence matrix."""
    rows = []
    lines = text.strip().splitlines()
    headers = []
    for line in lines:
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")[1:-1]]
        if not headers:
            headers = [h.lower().replace(" ", "_") for h in cells]
            continue
        if all(c.strip("-") == "" for c in cells):
            continue
        if cells and cells[0].strip() == "(none)":
            continue
        row = {}
        for i, h in enumerate(headers):
            row[h] = cells[i] if i < len(cells) else ""
        rows.append(row)
    return rows


def scan_directory(base: Path) -> List[Dict[str, Any]]:
    """Scan ~/Development/*/. claude/last-run-*.md files."""
    runs = []
    for project_dir in sorted(base.iterdir()):
        claude_dir = project_dir / ".claude"
        if not claude_dir.is_dir():
            continue
        for f in sorted(claude_dir.glob("last-run-*.md")):
            run = parse_run_file(f)
            if run:
                runs.append(run)
    return runs


def main():
    parser = argparse.ArgumentParser(description="Parse teamwork run logs")
    parser.add_argument("--scan-dir", default=str(Path.home() / "Development"),
                        help="Base directory to scan for projects")
    parser.add_argument("--file", help="Parse a single file")
    parser.add_argument("--output", help="Output JSONL file (default: stdout)")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON")
    args = parser.parse_args()

    if args.file:
        run = parse_run_file(Path(args.file))
        if run:
            runs = [run]
        else:
            print(f"Failed to parse: {args.file}", file=sys.stderr)
            sys.exit(1)
    else:
        runs = scan_directory(Path(args.scan_dir))

    output = sys.stdout
    if args.output:
        output = open(args.output, "w", encoding="utf-8")

    for run in runs:
        if args.pretty:
            json.dump(run, output, indent=2, ensure_ascii=False)
            output.write("\n")
        else:
            json.dump(run, output, ensure_ascii=False)
            output.write("\n")

    if args.output:
        output.close()
        print(f"Wrote {len(runs)} runs to {args.output}", file=sys.stderr)
    else:
        print(f"\n# {len(runs)} runs parsed", file=sys.stderr)


if __name__ == "__main__":
    main()
