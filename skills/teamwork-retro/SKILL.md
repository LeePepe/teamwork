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

- Optional: log path(s) (markdown retrospective or json/jsonl session log).
- If no path is provided, `.claude/last-run.md` in the repo root is auto-discovered.
- Multiple log files from one run may be provided.

## Workflow

1. Validate paths exist and are readable.
2. Resolve log path(s) and parse logs with:
   ```bash
   # Auto-discover last run log if no path provided
   LOG_PATH="${1:-}"
   if [ -z "$LOG_PATH" ]; then
     REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
     CANDIDATE=$(ls -t "$REPO_ROOT/.claude/last-run-"*.md 2>/dev/null | head -1)
     if [ -n "$CANDIDATE" ] && [ -f "$CANDIDATE" ]; then
       LOG_PATH="$CANDIDATE"
       echo "Auto-discovered run log: $LOG_PATH"
     fi
   fi
   python3 skills/teamwork-retro/scripts/teamwork_retro.py $LOG_PATH
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
