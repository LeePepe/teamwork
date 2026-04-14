---
description: Run a task through plan-led planning -> dual plan gate -> execute -> verify -> PM delivery gate -> final-review coalition.
argument-hint: "<task description>"
allowed-tools: Bash, Agent
---

If `${ARGUMENTS}` is empty, stop and return:
> Please provide a task description. Example: `/teamwork:task implement JWT auth middleware`

## Step 1 — Plugin Check

```bash
CODEX_SCRIPT=$(find ~/.claude/plugins -name "codex-companion.mjs" 2>/dev/null | head -1)
COPILOT_SCRIPT=$(find ~/.claude/plugins -name "copilot-companion.mjs" 2>/dev/null | head -1)

CODEX_OK=false
COPILOT_OK=false
[ -n "$CODEX_SCRIPT" ]   && CODEX_OK=true || true
[ -n "$COPILOT_SCRIPT" ] && COPILOT_OK=true || true

echo "codex=$CODEX_OK copilot=$COPILOT_OK"
```

Do not stop when both are false; team-lead will use Claude fallback.

## Step 2 — Read Team Config

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$REPO_ROOT" ] && cat "$REPO_ROOT/.claude/team.md" 2>/dev/null || echo "(no team.md)"
```

## Step 2.5 — Ensure `team-lead` Exists

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

If `team_lead=missing`, stop and ask user to run `/teamwork:setup` (or `bash scripts/setup.sh --repo`).

## Delegation Gate (Mandatory)

From this point, only orchestrate + summarize.
- Next action must be spawning `team-lead`.
- Do not implement `${ARGUMENTS}` locally.
- Do not use file-mutating tools in this handler.
- If delegation fails, stop and report the failure.

## Step 3 — Delegate to `team-lead`

Executor: `fullstack-engineer` auto-selects backend with priority (Copilot → Claude-native → Codex).

Spawn `team-lead` with:

```
Task: ${ARGUMENTS}
Routing preferences: <.claude/team.md or "use defaults">
Plugin availability: codex=<step1> copilot=<step1>
Executor: fullstack-engineer (Copilot → Claude-native → Codex tertiary fallback).
Verification preferences: <.claude/team.md ## Verification or "use plan task verification">
Planning policy: `plan-lead` may dispatch `designer` for design-heavy tasks before execution
Model config: <from .claude/team.md ## Model Config, or "no model overrides">
```

Wait for `team-lead` completion. Do not run independent implementation in this command.

## Step 4 — Report

Before return: if Step 2.5 had `temp=true`, run `rm -f "<path>"`.

Return:
- plan-lead planning summary (`research_status`, `design_status`)
- fallback strategy + selected model (if Claude fallback)
- plan path
- plan gate result (`plan-reviewer` + `pm`)
- PM delivery supervision result
- modified files
- failed/skipped tasks
- verifier result + command evidence
- final review result + key findings
- boundary violations (if any)
- suggested follow-up actions
- model config applied (role → model mappings used, or "no overrides")
