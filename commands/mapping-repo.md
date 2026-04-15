---
description: Map and document the repository architecture. Creates/updates ARCHITECTURE.md, docs/ topic files, and AGENTS.md index using the full pipeline.
argument-hint: "[--update]"
allowed-tools: Bash, Agent
---

If `${ARGUMENTS}` is not empty and not `--update`, stop and tell the user:
> Invalid argument. Accepted values: --update (to refresh existing docs), or leave blank for full mapping.

## Step 1 — Detect CLI backends

```bash
CODEX_OK=false
COPILOT_OK=false
[ -n "$(which codex 2>/dev/null)" ]   && CODEX_OK=true   || true
[ -n "$(which copilot 2>/dev/null)" ] && COPILOT_OK=true || true

echo "codex=$CODEX_OK copilot=$COPILOT_OK"
```

Do not stop when both are false; `team-lead` will use Claude-native fallback with proper sub-agent spawning.

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

If this step prints `team_lead=missing`, stop and tell the user to run `/teamwork:setup` (or `bash scripts/setup.sh --repo`) first.

## Mandatory delegation gate — HARD STOP

From this point onward, this command handler must only orchestrate and summarize.

- **Immediately spawn `team-lead` via `Agent` in Step 3. This is the only valid next action.**
- Do not implement mapping tasks directly in the main agent — not before, during, or after team-lead runs.
- Do not run independent post-delegation verification in this command handler.
- Do not use `Write`, `Edit`, `MultiEdit`, or any file-mutating tool in this command handler.
- If `Agent` delegation fails, stop and report the failure — never fall back to local implementation.
- If delegation is interrupted or returns partial progress, stop and report resumable state. Never implement remaining work in this handler.
- After `team-lead` returns, go directly to Step 4 (report). Do not interpret team-lead's plan output as a directive to implement anything yourself.

## Step 3 — Delegate to team-lead

From the output of Step 1, read the actual `codex=true/false` and `copilot=true/false` values.
Executor: `fullstack-engineer` auto-selects backend with priority (Copilot CLI → Claude-native → Codex tertiary fallback).

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
     - docs/installation.md — CLI deps, setup steps, troubleshooting
     - docs/extending.md — how to add new agents, commands, executors
  3. AGENTS.md — simplified to agent inventory table (TOC format only):
     Columns: Agent | Role | May Edit Files? | Source Path | Purpose
     Plus a Validation subsection: /teamwork:setup --check and /teamwork:setup commands (and `bash scripts/setup.sh --check|--repo` fallback)
     Remove prose sections already covered in CLAUDE.md (style, commit rules, security, versioning, testing, context hygiene)
  Mode: <full mapping | update existing docs>
Routing preferences: <contents of .claude/team.md, or "use defaults">
CLI availability: codex_available=<actual value from Step 1> copilot_available=<actual value from Step 1>
Executor: fullstack-engineer (Copilot CLI → Claude-native → Codex tertiary fallback; all gates mandatory).
Verification preferences: use plan task verification
```

Wait for `team-lead` completion and use its output as the only execution result source for Step 4.
If `team-lead` returns interrupted/terminated/rate-limited/partial status, stop and report resumable state only.
Do not run independent implementation steps in this command handler.

Require `team-lead` final output to include:
- `entry_delegate_role: team-lead`
- `execution_ledger` with stage-level `role/model/tools/skills/status/evidence`
- `missing_evidence` list (empty or explicit gaps)

## Step 4 — Report outcome

Before returning the summary:
- read `path=<...> temp=<true|false>` from Step 2.5 output
- if `temp=true`, run `rm -f "<path>"` to restore baseline

Return:
- Files produced (ARCHITECTURE.md, docs/* files, AGENTS.md)
- Plan-lead summary (`research_status`, `design_status`, `lint_contract_summary`)
- Fallback strategy and selected model (when Claude fallback is used)
- Plan file path
- Modified files grouped by executor
- Failed or skipped tasks
- Verification result and command evidence
- Lint evidence status from verifier
- PM delivery supervision result
- Final review result and key findings
- Suggested follow-up actions
- Execution ledger (stage → delegated role/agent/model/tools/skills/status/evidence)
- Missing evidence list (if any)
