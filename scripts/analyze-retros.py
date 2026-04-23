#!/usr/bin/env python3
"""analyze-retros.py — Analyze collected retrospective files and generate optimization suggestions.

Usage: python3 scripts/analyze-retros.py [retros_dir] [output_file]
"""

import os
import re
import sys
import json
from pathlib import Path
from collections import Counter, defaultdict


def parse_retro(content: str) -> dict:
    """Parse a retro markdown file into structured data."""
    retro = {
        "date": "",
        "project": "",
        "stages_run": "",
        "what_worked": [],
        "what_didnt": [],
        "accuracy_issues": [],
        "unnecessary_steps": [],
        "context_usage": "",
        "principles_compliance": {"reviewed": False, "plan_as_truth": False, "layered": False},
        "action_items": [],
    }

    current_section = None
    lines = content.split("\n")

    for line in lines:
        stripped = line.strip()

        # Header detection
        if stripped.startswith("## "):
            header = stripped[3:].strip().lower()
            if "worked" in header and "didn" not in header:
                current_section = "what_worked"
            elif "didn" in header or "not work" in header:
                current_section = "what_didnt"
            elif "accuracy" in header:
                current_section = "accuracy_issues"
            elif "unnecessary" in header:
                current_section = "unnecessary_steps"
            elif "context" in header:
                current_section = "context_usage"
            elif "principle" in header or "compliance" in header:
                current_section = "principles"
            elif "action" in header:
                current_section = "action_items"
            else:
                current_section = None
            continue

        # Metadata
        if stripped.startswith("- **Date**:"):
            retro["date"] = stripped.split(":", 1)[1].strip().strip("*")
        elif stripped.startswith("- **Project**:"):
            retro["project"] = stripped.split(":", 1)[1].strip().strip("*")
        elif stripped.startswith("- **Pipeline stages run**:"):
            retro["stages_run"] = stripped.split(":", 1)[1].strip().strip("*")

        # List items
        if stripped.startswith("- ") and current_section:
            item = stripped[2:].strip()
            if item.startswith("[") and current_section == "principles":
                checked = "x" in item[:4].lower()
                if "reviewed" in item.lower():
                    retro["principles_compliance"]["reviewed"] = checked
                elif "plan" in item.lower() and "truth" in item.lower():
                    retro["principles_compliance"]["plan_as_truth"] = checked
                elif "layered" in item.lower() or "context" in item.lower():
                    retro["principles_compliance"]["layered"] = checked
            elif current_section in ("what_worked", "what_didnt", "accuracy_issues",
                                      "unnecessary_steps", "action_items"):
                retro[current_section].append(item)
            elif current_section == "context_usage":
                retro["context_usage"] += item + " "

    return retro


def analyze_retros(retros: list[dict]) -> dict:
    """Analyze parsed retros and generate optimization suggestions."""
    if not retros:
        return {"suggestions": [], "summary": "No retros to analyze."}

    suggestions = []
    accuracy_issues = []
    unnecessary_steps = []
    what_worked_all = []
    what_didnt_all = []
    principle_violations = {"reviewed": 0, "plan_as_truth": 0, "layered": 0}

    for r in retros:
        accuracy_issues.extend(r["accuracy_issues"])
        unnecessary_steps.extend(r["unnecessary_steps"])
        what_worked_all.extend(r["what_worked"])
        what_didnt_all.extend(r["what_didnt"])
        pc = r["principles_compliance"]
        if not pc["reviewed"]:
            principle_violations["reviewed"] += 1
        if not pc["plan_as_truth"]:
            principle_violations["plan_as_truth"] += 1
        if not pc["layered"]:
            principle_violations["layered"] += 1

    total = len(retros)

    # Accuracy suggestions
    if accuracy_issues:
        suggestions.append({
            "area": "accuracy",
            "priority": "high",
            "finding": f"{len(accuracy_issues)} accuracy issues found across {total} retros",
            "details": accuracy_issues[:5],
            "recommendation": "Review and strengthen verification stage; add targeted checks for recurring issue types.",
        })

    # Unnecessary steps
    if unnecessary_steps:
        suggestions.append({
            "area": "unnecessary_steps",
            "priority": "medium",
            "finding": f"{len(unnecessary_steps)} unnecessary steps reported",
            "details": unnecessary_steps[:5],
            "recommendation": "Consider making reported stages conditional or skippable for matching task types.",
        })

    # Principle violations
    for principle, count in principle_violations.items():
        if count > 0:
            label = {
                "reviewed": "Content needs review",
                "plan_as_truth": "Plan+docs as source of truth",
                "layered": "Layered plan/docs to reduce context",
            }[principle]
            suggestions.append({
                "area": "principles",
                "priority": "high" if count > total // 2 else "medium",
                "finding": f"'{label}' not met in {count}/{total} retros",
                "recommendation": f"Reinforce '{label}' principle in agent definitions and pipeline checks.",
            })

    # Recurring failures
    if what_didnt_all:
        word_freq = Counter()
        for item in what_didnt_all:
            words = re.findall(r'\b\w{4,}\b', item.lower())
            word_freq.update(words)
        common = word_freq.most_common(5)
        if common:
            suggestions.append({
                "area": "recurring_failures",
                "priority": "medium",
                "finding": f"Common themes in failures: {', '.join(w for w, _ in common)}",
                "recommendation": "Investigate root causes for recurring failure themes.",
            })

    summary = (
        f"Analyzed {total} retros. "
        f"Found {len(accuracy_issues)} accuracy issues, "
        f"{len(unnecessary_steps)} unnecessary steps, "
        f"{len(suggestions)} optimization suggestions generated."
    )

    return {"suggestions": suggestions, "summary": summary, "total_retros": total}


def generate_report(analysis: dict) -> str:
    """Generate a markdown report from analysis results."""
    lines = ["# Retro Analysis Report\n"]
    lines.append(f"**Summary**: {analysis['summary']}\n")

    if not analysis["suggestions"]:
        lines.append("No optimization suggestions at this time.\n")
        return "\n".join(lines)

    lines.append("## Suggestions\n")
    for i, s in enumerate(analysis["suggestions"], 1):
        lines.append(f"### {i}. [{s['priority'].upper()}] {s['area'].replace('_', ' ').title()}\n")
        lines.append(f"**Finding**: {s['finding']}\n")
        if "details" in s:
            lines.append("**Details**:")
            for d in s["details"]:
                lines.append(f"- {d}")
            lines.append("")
        lines.append(f"**Recommendation**: {s['recommendation']}\n")

    return "\n".join(lines)


def main():
    retros_dir = sys.argv[1] if len(sys.argv) > 1 else "docs/retro-findings/collected"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "docs/retro-findings/analysis-report.md"

    retros_path = Path(retros_dir)
    if not retros_path.exists():
        print(f"Retros directory not found: {retros_dir}")
        print("Run scripts/collect-retros.sh first.")
        sys.exit(1)

    retro_files = list(retros_path.glob("*.md"))
    if not retro_files:
        print(f"No retro files found in {retros_dir}")
        sys.exit(1)

    print(f"Parsing {len(retro_files)} retro files...")
    retros = []
    for f in retro_files:
        content = f.read_text()
        retros.append(parse_retro(content))

    print("Analyzing...")
    analysis = analyze_retros(retros)

    report = generate_report(analysis)
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(report)

    print(f"Report written to {output_file}")
    print(analysis["summary"])

    # Also write JSON for programmatic use
    json_path = output_path.with_suffix(".json")
    json_path.write_text(json.dumps(analysis, indent=2))
    print(f"JSON data written to {json_path}")


if __name__ == "__main__":
    main()
