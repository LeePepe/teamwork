#!/usr/bin/env python3
"""analyze-retros.py — Unified retro analysis: qualitative (hand-written) + quantitative (run logs).

Usage:
    python3 scripts/analyze-retros.py [--output docs/retro-findings/analysis-report.md]

Data sources (all under ~/Development/teamwork/data/):
    - data/retros/collected/*.md  — hand-written project retros
    - data/runs.jsonl             — structured execution run logs
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, List

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DATA_DIR = REPO_ROOT / "data"

sys.path.insert(0, str(SCRIPT_DIR))
from eval_runs import evaluate_runs, generate_report as generate_eval_report  # type: ignore  # noqa: E402


# ============================================================
# Part 1: Qualitative analysis (hand-written retros)
# ============================================================

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

        if stripped.startswith("- **Date**:"):
            retro["date"] = stripped.split(":", 1)[1].strip().strip("*")
        elif stripped.startswith("- **Project**:"):
            retro["project"] = stripped.split(":", 1)[1].strip().strip("*")
        elif stripped.startswith("- **Pipeline stages run**:"):
            retro["stages_run"] = stripped.split(":", 1)[1].strip().strip("*")

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


def analyze_qualitative(retros: List[dict]) -> dict:
    """Analyze hand-written retros for patterns."""
    if not retros:
        return {"suggestions": [], "summary": "No hand-written retros found.", "total": 0}

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

    if accuracy_issues:
        suggestions.append({
            "area": "accuracy",
            "priority": "high",
            "finding": f"{len(accuracy_issues)} accuracy issues across {total} retros",
            "details": accuracy_issues[:5],
            "recommendation": "Review and strengthen verification stage.",
        })

    if unnecessary_steps:
        suggestions.append({
            "area": "unnecessary_steps",
            "priority": "medium",
            "finding": f"{len(unnecessary_steps)} unnecessary steps reported",
            "details": unnecessary_steps[:5],
            "recommendation": "Make reported stages conditional or skippable.",
        })

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
                "recommendation": f"Reinforce '{label}' in agent definitions.",
            })

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
                "finding": f"Common failure themes: {', '.join(w for w, _ in common)}",
                "recommendation": "Investigate root causes for recurring failures.",
            })

    return {
        "suggestions": suggestions,
        "total": total,
        "summary": f"{total} retros, {len(accuracy_issues)} accuracy issues, "
                   f"{len(unnecessary_steps)} unnecessary steps",
    }


# ============================================================
# Part 2: Unified report
# ============================================================

def generate_unified_report(qual: dict, eval_data: dict) -> str:
    """Generate a unified markdown report combining qualitative + quantitative."""
    lines = []
    lines.append("# Teamwork Retro Analysis Report")
    lines.append("")
    lines.append("综合分析：定性（手写 retro）+ 定量（执行日志）")
    lines.append("")

    # --- Quantitative section ---
    if eval_data.get("runs_total", 0) > 0:
        lines.append("---")
        lines.append("")
        lines.append(generate_eval_report(eval_data))
    else:
        lines.append("## Quantitative Analysis")
        lines.append("")
        lines.append("No execution run logs found in `data/runs.jsonl`.")
        lines.append("Run `bash scripts/collect-retros.sh` to collect.")
        lines.append("")

    # --- Qualitative section ---
    lines.append("---")
    lines.append("")
    lines.append("# Qualitative Analysis (Hand-written Retros)")
    lines.append("")

    if qual["total"] == 0:
        lines.append("No hand-written retros found in `data/retros/collected/`.")
        lines.append("Projects should place retros in `docs/retro/*.md`.")
        lines.append("")
    else:
        lines.append(f"**{qual['summary']}**")
        lines.append("")

        if qual["suggestions"]:
            lines.append("## Qualitative Suggestions")
            lines.append("")
            for i, s in enumerate(qual["suggestions"], 1):
                lines.append(f"### {i}. [{s['priority'].upper()}] {s['area'].replace('_', ' ').title()}")
                lines.append("")
                lines.append(f"**Finding**: {s['finding']}")
                lines.append("")
                if "details" in s:
                    for d in s["details"]:
                        lines.append(f"- {d}")
                    lines.append("")
                lines.append(f"**Recommendation**: {s['recommendation']}")
                lines.append("")

    # --- Cross-analysis ---
    lines.append("---")
    lines.append("")
    lines.append("## Cross-Analysis: Qualitative × Quantitative")
    lines.append("")

    cross = _cross_analyze(qual, eval_data)
    if cross:
        for i, insight in enumerate(cross, 1):
            lines.append(f"{i}. {insight}")
        lines.append("")
    else:
        lines.append("数据不足，无法交叉分析。积累更多 retro 和 run log 后再评估。")
        lines.append("")

    return "\n".join(lines)


def _cross_analyze(qual: dict, eval_data: dict) -> List[str]:
    """Find insights by crossing qualitative and quantitative data."""
    insights = []

    if eval_data.get("runs_total", 0) == 0 or qual["total"] == 0:
        return insights

    # Compare qualitative failure themes with quantitative bottlenecks
    bottlenecks = eval_data.get("bottlenecks", [])
    if bottlenecks:
        top_role = bottlenecks[0]["role"]
        qual_failures = [s for s in qual["suggestions"] if s["area"] == "recurring_failures"]
        if qual_failures:
            insights.append(
                f"定量瓶颈 **{top_role}** 与定性反馈中的失败主题可能相关，"
                "建议结合具体案例分析根因"
            )

    # Success rate vs principle compliance
    success_rate = eval_data.get("success_rate", 0)
    principle_issues = [s for s in qual["suggestions"] if s["area"] == "principles"]
    if success_rate < 50 and principle_issues:
        insights.append(
            f"成功率 {success_rate}% 偏低，且核心原则未充分遵守 — "
            "这两者可能互为因果"
        )

    # Iterate rate on reviewers vs accuracy issues
    accuracy_issues = [s for s in qual["suggestions"] if s["area"] == "accuracy"]
    role_summary = eval_data.get("role_summary", {})
    for role in ["plan-reviewer", "final-reviewer"]:
        stats = role_summary.get(role, {})
        if stats.get("iterate_rate", 0) > 30 and accuracy_issues:
            insights.append(
                f"**{role}** 迭代率 {stats['iterate_rate']}% + 定性报告中的准确性问题 → "
                "建议提升上游产出质量"
            )

    return insights


def main():
    parser = argparse.ArgumentParser(description="Unified retro analysis")
    parser.add_argument("--output", default="docs/retro-findings/analysis-report.md",
                        help="Output report path")
    parser.add_argument("--json-output", help="Output structured JSON")
    args = parser.parse_args()

    # 1. Qualitative: hand-written retros
    retro_dir = DATA_DIR / "retros" / "collected"
    retros = []
    if retro_dir.exists():
        for f in sorted(retro_dir.glob("*.md")):
            retros.append(parse_retro(f.read_text()))
    qual = analyze_qualitative(retros)
    print(f"Qualitative: {qual['summary']}")

    # 2. Quantitative: run logs
    runs_file = DATA_DIR / "runs.jsonl"
    runs = []
    if runs_file.exists():
        for line in runs_file.read_text().splitlines():
            line = line.strip()
            if line:
                runs.append(json.loads(line))
    eval_data = evaluate_runs(runs, days=90)
    print(f"Quantitative: {eval_data['runs_total']} runs, {eval_data.get('success_rate', 0)}% success")

    # 3. Unified report
    report = generate_unified_report(qual, eval_data)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(report, encoding="utf-8")
    print(f"\nReport → {output}")

    # 4. JSON
    if args.json_output:
        combined = {"qualitative": qual, "quantitative": eval_data}
        Path(args.json_output).write_text(
            json.dumps(combined, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(f"JSON → {args.json_output}")


if __name__ == "__main__":
    main()
