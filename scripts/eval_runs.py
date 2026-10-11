#!/usr/bin/env python3
"""Evaluate teamwork pipeline runs — quantitative analysis similar to Symphony retro-eval.

Usage:
    python3 eval-runs.py [--scan-dir ~/Development] [--days 30] [--output report.md]
    python3 eval-runs.py --jsonl runs.jsonl

Produces:
    - Overall success rate
    - Per-project breakdown
    - Per-agent role efficiency (pass/fail/iterate rates)
    - Bottleneck identification (most common failure/iterate stages)
    - Flow mode distribution
    - Trend analysis (if enough data)
    - Markdown report + structured JSON
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional

# Import the parser
sys.path.insert(0, str(Path(__file__).parent))
from parse_runs import parse_run_file, scan_directory  # type: ignore  # noqa: E402


def evaluate_runs(runs: List[Dict[str, Any]], days: int = 30) -> Dict[str, Any]:
    """Compute eval metrics from parsed runs."""
    if not runs:
        return {"error": "No runs found", "runs_total": 0}

    # Filter by time window
    cutoff = datetime.now() - timedelta(days=days)
    filtered = []
    for r in runs:
        ts = r.get("timestamp")
        if ts:
            try:
                dt = datetime.fromisoformat(ts)
                if dt >= cutoff:
                    filtered.append(r)
                    continue
            except (ValueError, TypeError):
                pass
        filtered.append(r)  # include runs without timestamp

    runs = filtered
    total = len(runs)

    # 1. Overall outcome distribution
    outcomes = Counter(r.get("outcome", "unknown") for r in runs)
    success_count = outcomes.get("pass", 0)
    success_rate = success_count / total * 100 if total else 0

    # 2. Per-project breakdown
    by_project: Dict[str, List] = defaultdict(list)
    for r in runs:
        by_project[r.get("project", "unknown")].append(r)

    project_stats = {}
    for proj, proj_runs in sorted(by_project.items()):
        proj_outcomes = Counter(r.get("outcome", "unknown") for r in proj_runs)
        proj_total = len(proj_runs)
        proj_success = proj_outcomes.get("pass", 0)
        project_stats[proj] = {
            "total": proj_total,
            "success": proj_success,
            "success_rate": round(proj_success / proj_total * 100, 1) if proj_total else 0,
            "outcomes": dict(proj_outcomes),
        }

    # 3. Per-role analysis
    role_stats: Dict[str, Dict[str, int]] = defaultdict(lambda: {
        "total": 0, "pass": 0, "fail": 0, "iterate": 0, "skip": 0, "interrupted": 0,
    })
    for r in runs:
        for stage in r.get("stages", []):
            role = stage.get("role", "unknown")
            status = stage.get("status", "unknown").lower()
            role_stats[role]["total"] += 1
            if status in ("pass", "pass-with-nit"):
                role_stats[role]["pass"] += 1
            elif "fail" in status:
                role_stats[role]["fail"] += 1
            elif "iterate" in status:
                role_stats[role]["iterate"] += 1
            elif status == "skipped":
                role_stats[role]["skip"] += 1
            elif status == "interrupted":
                role_stats[role]["interrupted"] += 1

    # Compute pass rates per role
    role_summary = {}
    for role, stats in sorted(role_stats.items()):
        active = stats["total"] - stats["skip"] - stats["interrupted"]
        role_summary[role] = {
            **stats,
            "active": active,
            "pass_rate": round(stats["pass"] / active * 100, 1) if active else 0,
            "iterate_rate": round(stats["iterate"] / active * 100, 1) if active else 0,
        }

    # 4. Bottleneck identification
    bottlenecks = []
    for role, stats in role_summary.items():
        if role in ("unknown",):
            continue
        score = stats["fail"] * 3 + stats["iterate"] * 1
        if score > 0:
            bottlenecks.append({
                "role": role,
                "score": score,
                "fails": stats["fail"],
                "iterates": stats["iterate"],
                "pass_rate": stats["pass_rate"],
            })
    bottlenecks.sort(key=lambda x: x["score"], reverse=True)

    # 5. Flow mode distribution
    flow_modes = Counter()
    for r in runs:
        flow = r.get("flow", "unknown")
        if "standard" in flow.lower():
            flow_modes["standard"] += 1
        elif "plan-only" in flow.lower():
            flow_modes["plan-only"] += 1
        elif "execute" in flow.lower():
            flow_modes["execute-from-plan"] += 1
        else:
            flow_modes[flow] += 1

    # 6. Tools & Skills usage
    tool_usage = Counter()
    skill_usage = Counter()
    for r in runs:
        for t in r.get("tools", []):
            tool_usage[t] += 1
        for s in r.get("skills", []):
            skill_usage[s] += 1

    # 7. Efficiency score (0-10)
    efficiency = _compute_efficiency_score(
        success_rate, bottlenecks, total, role_summary
    )

    return {
        "eval_timestamp": datetime.now().isoformat(),
        "period_days": days,
        "runs_total": total,
        "success_rate": round(success_rate, 1),
        "outcomes": dict(outcomes),
        "efficiency_score": efficiency,
        "project_stats": project_stats,
        "role_summary": role_summary,
        "bottlenecks": bottlenecks[:5],  # top 5
        "flow_modes": dict(flow_modes),
        "tool_usage": dict(tool_usage.most_common(10)),
        "skill_usage": dict(skill_usage.most_common(10)),
    }


def _compute_efficiency_score(
    success_rate: float,
    bottlenecks: List[Dict],
    total_runs: int,
    role_summary: Dict,
) -> int:
    """Compute 0-10 efficiency score."""
    score = 0.0

    # Success rate contributes 0-5 points
    score += min(success_rate / 20, 5.0)

    # Low bottleneck score contributes 0-2 points
    total_bottleneck = sum(b["score"] for b in bottlenecks)
    if total_bottleneck == 0:
        score += 2.0
    elif total_bottleneck < 5:
        score += 1.5
    elif total_bottleneck < 10:
        score += 1.0

    # Data sufficiency contributes 0-1 point
    if total_runs >= 10:
        score += 1.0
    elif total_runs >= 5:
        score += 0.5

    # High role pass rates contribute 0-2 points
    critical_roles = ["fullstack-engineer", "verifier", "final-reviewer"]
    role_bonus = 0
    for role in critical_roles:
        if role in role_summary and role_summary[role]["pass_rate"] >= 80:
            role_bonus += 0.67
    score += min(role_bonus, 2.0)

    return min(round(score), 10)


def generate_report(eval_data: Dict[str, Any]) -> str:
    """Generate markdown report from eval data."""
    lines = []
    lines.append(f"# Teamwork Pipeline Eval Report")
    lines.append(f"")
    lines.append(f"**Generated:** {eval_data['eval_timestamp']}")
    lines.append(f"**Period:** last {eval_data['period_days']} days")
    lines.append(f"**Total runs:** {eval_data['runs_total']}")
    lines.append(f"**Success rate:** {eval_data['success_rate']}%")
    lines.append(f"**Efficiency score:** {eval_data['efficiency_score']}/10")
    lines.append("")

    # Outcomes
    lines.append("## Outcome Distribution")
    lines.append("")
    for outcome, count in sorted(eval_data["outcomes"].items(), key=lambda x: -x[1]):
        pct = round(count / eval_data["runs_total"] * 100, 1)
        lines.append(f"- **{outcome}**: {count} ({pct}%)")
    lines.append("")

    # Per-project
    lines.append("## Per-Project Breakdown")
    lines.append("")
    lines.append("| Project | Runs | Success | Rate |")
    lines.append("|---------|------|---------|------|")
    for proj, stats in sorted(eval_data["project_stats"].items()):
        lines.append(f"| {proj} | {stats['total']} | {stats['success']} | {stats['success_rate']}% |")
    lines.append("")

    # Role analysis
    lines.append("## Agent Role Efficiency")
    lines.append("")
    lines.append("| Role | Active | Pass | Fail | Iterate | Pass Rate |")
    lines.append("|------|--------|------|------|---------|-----------|")
    for role, stats in sorted(eval_data["role_summary"].items(),
                               key=lambda x: -x[1].get("active", 0)):
        if stats["active"] == 0:
            continue
        lines.append(
            f"| {role} | {stats['active']} | {stats['pass']} | "
            f"{stats['fail']} | {stats['iterate']} | {stats['pass_rate']}% |"
        )
    lines.append("")

    # Bottlenecks
    if eval_data["bottlenecks"]:
        lines.append("## Top Bottlenecks")
        lines.append("")
        for i, b in enumerate(eval_data["bottlenecks"], 1):
            severity = "🔴" if b["score"] >= 5 else "🟡" if b["score"] >= 2 else "🟢"
            lines.append(
                f"{i}. {severity} **{b['role']}** — {b['fails']} fails, "
                f"{b['iterates']} iterates (pass rate: {b['pass_rate']}%)"
            )
        lines.append("")

    # Flow modes
    lines.append("## Flow Mode Distribution")
    lines.append("")
    for mode, count in sorted(eval_data["flow_modes"].items(), key=lambda x: -x[1]):
        lines.append(f"- **{mode}**: {count}")
    lines.append("")

    # Suggestions
    lines.append("## Improvement Suggestions")
    lines.append("")
    suggestions = _generate_suggestions(eval_data)
    for i, s in enumerate(suggestions, 1):
        lines.append(f"{i}. {s}")
    lines.append("")

    return "\n".join(lines)


def _generate_suggestions(eval_data: Dict[str, Any]) -> List[str]:
    """Generate improvement suggestions based on eval data."""
    suggestions = []

    # Low success rate
    if eval_data["success_rate"] < 70:
        suggestions.append(
            f"整体成功率 {eval_data['success_rate']}% 偏低，"
            "建议检查 preflight 阶段是否充分验证环境（sub-agent 工具、role 文件完整性）"
        )

    # Bottleneck roles
    for b in eval_data["bottlenecks"][:3]:
        if b["score"] >= 3:
            suggestions.append(
                f"**{b['role']}** 是主要瓶颈（{b['fails']} 次失败，{b['iterates']} 次迭代），"
                "建议：加强该 agent 的 prompt/约束或增加 retry 逻辑"
            )

    # High iterate rate on reviewers
    for role in ["plan-reviewer", "final-reviewer", "pm"]:
        stats = eval_data["role_summary"].get(role, {})
        if stats.get("iterate_rate", 0) > 50:
            suggestions.append(
                f"**{role}** 迭代率 {stats['iterate_rate']}% 过高，"
                "建议：提升上游产出质量以减少 review 轮次"
            )

    # Too many interrupted runs
    interrupted = eval_data["outcomes"].get("interrupted", 0)
    if interrupted > 0 and interrupted / eval_data["runs_total"] > 0.2:
        pct = round(interrupted / eval_data["runs_total"] * 100, 1)
        suggestions.append(
            f"{pct}% 的 run 被中断，建议改善 preflight 检查和错误容忍度"
        )

    if not suggestions:
        suggestions.append("当前数据量较少或表现良好，持续积累数据后再评估")

    return suggestions


def main():
    parser = argparse.ArgumentParser(description="Evaluate teamwork pipeline runs")
    parser.add_argument("--scan-dir", default=str(Path.home() / "Development"))
    parser.add_argument("--jsonl", help="Read from JSONL file instead of scanning")
    parser.add_argument("--days", type=int, default=30, help="Analysis window (days)")
    parser.add_argument("--output", help="Output report file (markdown)")
    parser.add_argument("--json-output", help="Output structured JSON")
    args = parser.parse_args()

    # Default: read from central JSONL store; fall back to live scan
    default_store = Path(__file__).resolve().parent.parent / "data" / "runs.jsonl"
    jsonl = args.jsonl or (str(default_store) if default_store.exists() else None)

    if jsonl:
        runs = []
        with open(jsonl, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    runs.append(json.loads(line))
    else:
        runs = scan_directory(Path(args.scan_dir))

    eval_data = evaluate_runs(runs, days=args.days)
    report = generate_report(eval_data)

    # Output markdown
    if args.output:
        Path(args.output).write_text(report, encoding="utf-8")
        print(f"Report written to {args.output}", file=sys.stderr)
    else:
        print(report)

    # Output JSON
    if args.json_output:
        Path(args.json_output).write_text(
            json.dumps(eval_data, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(f"JSON written to {args.json_output}", file=sys.stderr)


if __name__ == "__main__":
    main()
