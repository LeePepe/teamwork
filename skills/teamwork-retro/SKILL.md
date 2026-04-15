---
name: teamwork-retro
description: Use when auditing a completed teamwork run and you need log-grounded per-agent role/model/tool/skill evidence plus compliance gaps against current teamwork rules.
allowed-tools: Bash, Read
---

# Teamwork Retro

Run a structured retrospective from execution logs and output a complete per-agent ledger.

## Triggers

```text
retro
retrospective
execution replay
what happened in this teamwork run
```

Natural language trigger:

```text
Review this teamwork run and show each agent's role/model/tool/skill usage.
```

## Inputs

- Required: at least one log path (markdown retrospective or json/jsonl session log).
- Optional: multiple log files from one run.

## Workflow

1. Validate paths exist and are readable.
2. Parse logs with:
   ```bash
   python3 skills/teamwork-retro/scripts/teamwork_retro.py <log-path> [more-paths...]
   ```
3. Return:
   - Per-agent table: `agent`, `role`, `model`, `tools`, `skills`, `evidence`.
   - Session-level tools and skills.
   - Compliance checks against current teamwork/team-lead constraints.
4. If fields are missing in logs, explicitly mark `unknown` and list what evidence should be added next run.

## Hard Constraints

- Retrospective must be evidence-based (only from provided logs).
- Do not infer gate pass/fail without explicit log traces.
- Always report missing evidence as a finding, not as success.
