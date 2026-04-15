#!/usr/bin/env python3
"""Summarize teamwork execution logs into per-agent metadata and compliance checks."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any


MANDATORY_STAGES = [
    "plan-lead",
    "plan-reviewer",
    "pm",
    "fullstack-engineer",
    "verifier",
    "final-reviewer",
]


@dataclass
class AgentRecord:
    agent: str
    role: str = "unknown"
    model: str = "unknown"
    tools: set[str] = field(default_factory=set)
    skills: set[str] = field(default_factory=set)
    evidence: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "agent": self.agent,
            "role": self.role,
            "model": self.model,
            "tools": sorted(self.tools),
            "skills": sorted(self.skills),
            "evidence": self.evidence,
        }


class RetroState:
    def __init__(self) -> None:
        self.agents: dict[str, AgentRecord] = {}
        self.session_tools: set[str] = set()
        self.session_skills: set[str] = set()
        self.stage_mentions: set[str] = set()
        self.explicit_missing_stages: set[str] = set()
        self.raw_text_by_path: dict[str, str] = {}

    def upsert_agent(self, key: str) -> AgentRecord:
        if key not in self.agents:
            self.agents[key] = AgentRecord(agent=key)
        return self.agents[key]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze teamwork logs and print per-agent role/model/tool/skill details."
    )
    parser.add_argument("paths", nargs="+", help="Log file paths (markdown/json/jsonl)")
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    return parser.parse_args()


def read_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def parse_markdown_sections(text: str) -> dict[str, list[str]]:
    sections: dict[str, list[str]] = defaultdict(list)
    current = "__ROOT__"
    for line in text.splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            continue
        sections[current].append(line.rstrip())
    return sections


def extract_code_tokens(line: str) -> list[str]:
    return re.findall(r"`([^`]+)`", line)


def is_skill_token(token: str) -> bool:
    return bool(re.fullmatch(r"[a-z0-9-]+:[a-z0-9-]+", token))


def parse_markdown_log(path: str, text: str, state: RetroState) -> None:
    sections = parse_markdown_sections(text)

    # Agent basics
    role_lines = sections.get("Roles / Agents / Models", [])
    delegation_lines = sections.get("Flow", [])

    for ln in role_lines:
        m = re.search(r"Primary orchestrator role:\s*(.+?)\.?$", ln)
        if m:
            agent = state.upsert_agent("main")
            agent.role = m.group(1).strip()
            agent.evidence.append(f"{path}: {ln.strip()}")
        m = re.search(r"Delegated worker:\s*`([^`]+)`", ln)
        if m:
            agent = state.upsert_agent(m.group(1))
            if agent.role == "unknown":
                agent.role = "delegated worker"
            agent.evidence.append(f"{path}: {ln.strip()}")

    full_text = text
    m_agent_id = re.search(r"`agent_id`:\s*`([^`]+)`", full_text)
    m_nickname = re.search(r"nickname:\s*`([^`]+)`", full_text)
    if m_agent_id:
        key = m_nickname.group(1) if m_nickname else m_agent_id.group(1)
        agent = state.upsert_agent(key)
        agent.evidence.append(f"{path}: agent_id={m_agent_id.group(1)}")
        if m_nickname:
            agent.evidence.append(f"{path}: nickname={m_nickname.group(1)}")

    # Model notes
    inherited = re.search(r"inherited the parent session model", full_text, re.IGNORECASE)
    no_override = re.search(r"No explicit per-agent model override", full_text, re.IGNORECASE)
    if "main" in state.agents:
        main = state.agents["main"]
        if no_override:
            main.model = "parent session model (no override recorded)"
            main.evidence.append(f"{path}: no explicit per-agent model override")
    if inherited:
        for key, agent in state.agents.items():
            if key != "main" and agent.model == "unknown":
                agent.model = "inherited parent session model"
                agent.evidence.append(f"{path}: inherited parent session model")

    # Skills
    skill_lines = sections.get("Skills Used", [])
    for ln in skill_lines:
        tokens = extract_code_tokens(ln)
        for token in tokens:
            if is_skill_token(token):
                state.session_skills.add(token)

    # Tools
    tool_lines = sections.get("Tools Used", [])
    collect_tools = True
    for ln in tool_lines:
        if ln.strip().lower().startswith("not used in this run"):
            collect_tools = False
            continue
        if not collect_tools:
            continue
        tokens = extract_code_tokens(ln)
        for token in tokens:
            state.session_tools.add(token)

    # Stage mentions (for compliance checks)
    stage_signal_sections = [
        "Flow",
        "Roles / Agents / Models",
        "Execution Ledger",
        "Stage Execution Ledger",
        "Execution Evidence Contract",
    ]
    scan_lines: list[str] = []
    for sec in stage_signal_sections:
        scan_lines.extend(sections.get(sec, []))
    scan_blob = "\n".join(scan_lines).lower()
    for stage in ["team-lead"] + MANDATORY_STAGES + ["git-monitor"]:
        if stage in scan_blob:
            state.stage_mentions.add(stage)

    # Parse explicit missing evidence matrix rows (if provided)
    for ln in sections.get("Missing Evidence Matrix", []):
        if "|" not in ln:
            continue
        if re.match(r"^\|\s*-+\s*\|", ln):
            continue
        cols = [c.strip() for c in ln.strip().strip("|").split("|")]
        if len(cols) < 2:
            continue
        stage = cols[0].lower()
        if stage in {"stage", ""}:
            continue
        row_blob = " ".join(cols).lower()
        if "not captured" in row_blob or row_blob.count("unknown") >= 3:
            state.explicit_missing_stages.add(stage)

    # Parse explicit execution ledger rows to capture stage evidence
    for sec in ("Execution Ledger", "Stage Execution Ledger", "Execution Evidence Contract"):
        for ln in sections.get(sec, []):
            if "|" not in ln:
                continue
            if re.match(r"^\|\s*-+\s*\|", ln):
                continue
            cols = [c.strip() for c in ln.strip().strip("|").split("|")]
            if len(cols) < 2:
                continue
            stage = cols[0].lower()
            if stage in {"stage", ""}:
                continue
            row_blob = " ".join(cols).lower()
            if "not captured" in row_blob:
                state.explicit_missing_stages.add(stage)
                continue
            if row_blob.count("unknown") >= 3:
                continue
            state.stage_mentions.add(stage)


def _extract_from_obj(obj: Any, state: RetroState, path: str) -> None:
    if isinstance(obj, dict):
        recipient = obj.get("recipient_name")
        if isinstance(recipient, str):
            state.session_tools.add(recipient)
            if recipient.endswith("spawn_agent"):
                params = obj.get("parameters", {})
                agent_type = "default"
                model = "inherited parent session model"
                message = ""
                if isinstance(params, dict):
                    agent_type = str(params.get("agent_type", "default"))
                    if params.get("model"):
                        model = str(params["model"])
                    if isinstance(params.get("message"), str):
                        message = params["message"]
                key = f"spawned:{agent_type}"
                rec = state.upsert_agent(key)
                if rec.role == "unknown":
                    rec.role = agent_type
                if rec.model == "unknown":
                    rec.model = model
                rec.evidence.append(f"{path}: {recipient}")
                for stage in ["team-lead"] + MANDATORY_STAGES + ["git-monitor"]:
                    if stage in message.lower():
                        state.stage_mentions.add(stage)
                for match in re.findall(r"[a-z0-9-]+:[a-z0-9-]+", message):
                    state.session_skills.add(match)

        for value in obj.values():
            _extract_from_obj(value, state, path)
        return

    if isinstance(obj, list):
        for item in obj:
            _extract_from_obj(item, state, path)
        return

    if isinstance(obj, str):
        low = obj.lower()
        for stage in ["team-lead"] + MANDATORY_STAGES + ["git-monitor"]:
            if stage in low:
                state.stage_mentions.add(stage)
        for match in re.findall(r"[a-z0-9-]+:[a-z0-9-]+", obj):
            state.session_skills.add(match)


def parse_json_like(path: str, text: str, state: RetroState) -> bool:
    parsed_any = False
    try:
        obj = json.loads(text)
        _extract_from_obj(obj, state, path)
        parsed_any = True
    except json.JSONDecodeError:
        pass

    if not parsed_any:
        lines = [ln for ln in text.splitlines() if ln.strip()]
        jsonl_parsed = False
        for ln in lines:
            try:
                obj = json.loads(ln)
            except json.JSONDecodeError:
                continue
            _extract_from_obj(obj, state, path)
            jsonl_parsed = True
        parsed_any = jsonl_parsed
    return parsed_any


def enrich_agents_with_session_defaults(state: RetroState) -> None:
    if not state.agents:
        state.upsert_agent("main")

    for agent in state.agents.values():
        if state.session_tools and not agent.tools:
            agent.tools.update(state.session_tools)
            agent.evidence.append("session-level tools (not attributable per agent)")
        if state.session_skills and not agent.skills:
            agent.skills.update(state.session_skills)
            agent.evidence.append("session-level skills (not attributable per agent)")
        if agent.model == "unknown":
            agent.model = "unknown (not in logs)"


def compliance_checks(state: RetroState, paths: list[str]) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []

    # team-lead delegation
    has_team_lead = "team-lead" in state.stage_mentions and any(
        ("team-lead" in a.role.lower()) or ("team-lead" in a.agent.lower())
        for a in state.agents.values()
    )
    findings.append(
        {
            "check": "Delegated via team-lead",
            "status": "PASS" if has_team_lead else "FAIL",
            "evidence": "Explicit team-lead agent delegation found"
            if has_team_lead
            else "No explicit team-lead agent delegation evidence",
        }
    )

    # mandatory stages
    missing = [
        stage
        for stage in MANDATORY_STAGES
        if stage not in state.stage_mentions or stage in state.explicit_missing_stages
    ]
    findings.append(
        {
            "check": "Mandatory stages present in logs",
            "status": "PASS" if not missing else "FAIL",
            "evidence": "all mandatory stages present" if not missing else f"missing: {', '.join(missing)}",
        }
    )

    # main-thread takeover smell (markdown phrase heuristic)
    main_thread_takeover = False
    for text in state.raw_text_by_path.values():
        low = text.lower()
        if "main-thread" in low and ("verification" in low or "inspection" in low):
            main_thread_takeover = True
            break
    findings.append(
        {
            "check": "No main-thread stage takeover",
            "status": "PASS" if not main_thread_takeover else "WARN",
            "evidence": "No takeover phrases found"
            if not main_thread_takeover
            else "Found main-thread verification/inspection phrases; verify stage ownership",
        }
    )

    # model traceability
    unknown_models = [a.agent for a in state.agents.values() if a.model.startswith("unknown")]
    findings.append(
        {
            "check": "Model traceability per agent",
            "status": "PASS" if not unknown_models else "WARN",
            "evidence": "all agents have model traceability"
            if not unknown_models
            else f"missing model evidence: {', '.join(unknown_models)}",
        }
    )

    findings.append(
        {
            "check": "Input coverage",
            "status": "INFO",
            "evidence": ", ".join(paths),
        }
    )
    return findings


def render_markdown(state: RetroState, checks: list[dict[str, str]]) -> str:
    lines: list[str] = []
    lines.append("## Agent Ledger")
    lines.append("| Agent | Role | Model | Tools | Skills | Evidence |")
    lines.append("|---|---|---|---|---|---|")
    for agent in sorted(state.agents.values(), key=lambda a: a.agent):
        tools = ", ".join(sorted(agent.tools)) if agent.tools else "unknown"
        skills = ", ".join(sorted(agent.skills)) if agent.skills else "unknown"
        evidence = "; ".join(agent.evidence[:3]) if agent.evidence else "none"
        lines.append(
            f"| {agent.agent} | {agent.role} | {agent.model} | {tools} | {skills} | {evidence} |"
        )

    lines.append("")
    lines.append("## Session Tools")
    if state.session_tools:
        for tool in sorted(state.session_tools):
            lines.append(f"- `{tool}`")
    else:
        lines.append("- none")

    lines.append("")
    lines.append("## Session Skills")
    if state.session_skills:
        for skill in sorted(state.session_skills):
            lines.append(f"- `{skill}`")
    else:
        lines.append("- none")

    lines.append("")
    lines.append("## Compliance Checks")
    lines.append("| Check | Status | Evidence |")
    lines.append("|---|---|---|")
    for item in checks:
        lines.append(f"| {item['check']} | {item['status']} | {item['evidence']} |")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    state = RetroState()
    missing_paths = [p for p in args.paths if not os.path.exists(p)]
    if missing_paths:
        for p in missing_paths:
            print(f"ERROR: file not found: {p}", file=sys.stderr)
        return 2

    for path in args.paths:
        text = read_file(path)
        state.raw_text_by_path[path] = text
        ext = os.path.splitext(path)[1].lower()
        if ext in {".md", ".markdown"}:
            parse_markdown_log(path, text, state)
            continue
        if ext in {".json", ".jsonl", ".log", ".txt"}:
            parsed = parse_json_like(path, text, state)
            if not parsed and ext in {".log", ".txt"}:
                # best-effort parse by simple text patterns
                parse_markdown_log(path, text, state)
            continue
        # Default best effort
        if not parse_json_like(path, text, state):
            parse_markdown_log(path, text, state)

    enrich_agents_with_session_defaults(state)
    checks = compliance_checks(state, args.paths)

    result = {
        "agents": [a.as_dict() for a in sorted(state.agents.values(), key=lambda x: x.agent)],
        "session_tools": sorted(state.session_tools),
        "session_skills": sorted(state.session_skills),
        "checks": checks,
    }

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    print(render_markdown(state, checks))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
