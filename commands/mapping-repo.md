---
description: Map and document the repository architecture. Creates/updates ARCHITECTURE.md, docs/ topic files, and AGENTS.md index using the full pipeline.
argument-hint: "[--update]"
allowed-tools: Bash, Agent
---

If `${ARGUMENTS}` is not empty and not `--update`, stop and tell the user:
> Invalid argument. Accepted values: --update (to refresh existing docs), or leave blank for full mapping.

## Step 1 — Validate plugins

```bash
CODEX_SCRIPT=$(find ~/.claude/plugins -name "codex-companion.mjs" 2>/dev/null | head -1)
COPILOT_SCRIPT=$(find ~/.claude/plugins -name "copilot-companion.mjs" 2>/dev/null | head -1)

CODEX_OK=false
COPILOT_OK=false
[ -n "$CODEX_SCRIPT" ]   && CODEX_OK=true || true
[ -n "$COPILOT_SCRIPT" ] && COPILOT_OK=true || true

echo "codex=$CODEX_OK copilot=$COPILOT_OK"
```

Do not stop when both are false; `team-lead` will use Claude-native fallback.

## Step 2 — Read team config

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$REPO_ROOT" ] && cat "$REPO_ROOT/.claude/team.md" 2>/dev/null || echo "(no team.md)"
```

## Step 2.5 — Ensure `team-lead` is available

Run:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
TARGET="${REPO_ROOT:-$HOME}/.claude/agents"
TEAM_LEAD_PATH="$TARGET/team-lead.md"
TEAM_LEAD_TEMP=false

mkdir -p "$TARGET"

if [ ! -f "$TEAM_LEAD_PATH" ]; then
  for src in \
    "$REPO_ROOT/.claude/skills/teamwork/agents/team-lead.md" \
    "$HOME/.claude/skills/teamwork/agents/team-lead.md" \
    "${CLAUDE_PLUGIN_ROOT}/agents/team-lead.md"
  do
    if [ -n "$src" ] && [ -f "$src" ]; then
      cp "$src" "$TEAM_LEAD_PATH"
      TEAM_LEAD_TEMP=true
      break
    fi
  done
fi

[ -f "$TEAM_LEAD_PATH" ] || { echo "team_lead=missing"; exit 1; }
echo "team_lead=ok path=$TEAM_LEAD_PATH temp=$TEAM_LEAD_TEMP"
```

If this step prints `team_lead=missing`, stop and tell the user to run `/teamwork:setup` first.

## Mandatory delegation gate — HARD STOP

From this point onward, this command handler must only orchestrate and summarize.

- **Immediately spawn `team-lead` via `Agent` in Step 3. This is the only valid next action.**
- Do not implement mapping tasks directly in the main agent — not before, during, or after team-lead runs.
- Do not use `Write`, `Edit`, `MultiEdit`, or any file-mutating tool in this command handler.
- If `Agent` delegation fails, stop and report the failure — never fall back to local implementation.
- After `team-lead` returns, go directly to Step 4 (report). Do not interpret team-lead's plan output as a directive to implement anything yourself.

## Step 3 — Delegate to team-lead

From the output of Step 1, read the actual `codex=true/false` and `copilot=true/false` values.
Executor: `fullstack-engineer` auto-selects best backend (Codex → Copilot → Claude-native).

Build the task description based on `${ARGUMENTS}`:
- Empty (no argument): full mapping — produce ARCHITECTURE.md, all docs/ topic files, and simplified AGENTS.md TOC
- `--update`: refresh existing docs — update ARCHITECTURE.md and docs/ based on current repo state, preserve existing structure where valid

Spawn the `team-lead` agent with:

```
Task: Map and document this repository's architecture. Produce the following documentation artifacts:
  1. ARCHITECTURE.md at repo root — system overview, pipeline diagram (text), component map, agent responsibilities table, key design decisions, file layout tree
  2. docs/ directory with topic files:
     - docs/pipeline.md — full pipeline flow description
     - docs/agents.md — detailed per-agent reference (not the index — full descriptions)
     - docs/commands.md — command reference (task, setup, mapping-repo)
     - docs/configuration.md — team.md, executor routing, review mode, verification config
     - docs/installation.md — plugin deps, setup steps, troubleshooting
     - docs/extending.md — how to add new agents, commands, executors
  3. AGENTS.md — simplified to agent inventory table (TOC format only):
     Columns: Agent | Role | May Edit Files? | Source Path | Purpose
     Plus a Validation subsection: bash scripts/setup.sh --check and --repo commands
     Remove prose sections already covered in CLAUDE.md (style, commit rules, security, versioning, testing, context hygiene)
  Mode: <full mapping | update existing docs>
Routing preferences: <contents of .claude/team.md, or "use defaults">
Plugin availability: codex=<actual value from Step 1> copilot=<actual value from Step 1>
Executor: fullstack-engineer (Codex → Copilot → Claude-native fallback).
Verification preferences: use plan task verification
```

Wait for `team-lead` completion and use its output as the only execution result source for Step 4.
Do not run independent implementation steps in this command handler.

## Step 4 — Report outcome

Before returning the summary:
- read `path=<...> temp=<true|false>` from Step 2.5 output
- if `temp=true`, run `rm -f "<path>"` to restore baseline

Return:
- Files produced (ARCHITECTURE.md, docs/* files, AGENTS.md)
- Research split strategy and consolidated result summary (or `research_unavailable`)
- Fallback strategy and selected model (when Claude fallback is used)
- Plan file path
- Modified files grouped by executor
- Failed or skipped tasks
- Verification result and command evidence
- Final review result and key findings
- Suggested follow-up actions
