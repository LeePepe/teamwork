---
description: Run a task through the full research → plan → review → design (when needed) → execute → verify → final-review pipeline. Pass your task description as the argument.
argument-hint: "<task description>"
allowed-tools: Bash, Agent
---

If `${ARGUMENTS}` is empty, stop and tell the user:
> Please provide a task description. Example: `/teamwork:task implement JWT auth middleware`

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
- Do not implement `${ARGUMENTS}` directly in the main agent — not before, during, or after team-lead runs.
- Do not use `Write`, `Edit`, `MultiEdit`, or any file-mutating tool in this command handler.
- Do not read file contents for implementation purposes; Step 2.5 exists only to ensure team-lead is available.
- The only allowed direct repo mutation after Step 2.5 is temporary `team-lead.md` cleanup in Step 4.
- If `Agent` delegation fails, stop and report the failure — never fall back to local implementation.
- After `team-lead` returns, go directly to Step 4 (report). Do not interpret team-lead's plan output as a directive to implement anything yourself.

## Step 3 — Delegate to team-lead

From the output of Step 1, read the actual `codex=true/false` and `copilot=true/false` values.
Derive the executor constraint:
- Both true → route per plan annotation (default behavior)
- Copilot false + Codex true → all tasks go to `codex-coder` (including research/review fallback where applicable)
- Codex false + Copilot true → all tasks go to `copilot` (plan/final review may fallback to Claude-native)
- Both false → all tasks go to `claude-coder`; lead selects Claude model

Spawn the `team-lead` agent with:

```
Task: ${ARGUMENTS}
Routing preferences: <contents of .claude/team.md, or "use defaults">
Plugin availability: codex=<actual value from Step 1> copilot=<actual value from Step 1>
Executor constraint: <derived from above>
Verification preferences: <commands from .claude/team.md ## Verification, or "use plan task verification">
Claude fallback model policy: lead selects `haiku|sonnet|opus` when both plugins are unavailable
Design-first policy: when task requires design output, delegate to `designer` first, generate a design plan, then execute
```

Wait for `team-lead` completion and use its output as the only execution result source for Step 4.
Do not run independent implementation steps in this command handler.

## Step 4 — Report outcome

Before returning the summary:
- read `path=<...> temp=<true|false>` from Step 2.5 output
- if `temp=true`, run `rm -f "<path>"` to restore baseline

Return:
- Research split strategy and consolidated result summary (or `research_unavailable`)
- Fallback strategy and selected model (when Claude fallback is used)
- Plan file path
- Design-stage result (`used|skipped`) and design plan path (if used)
- Modified files grouped by executor
- Failed or skipped tasks
- Verification result and command evidence
- Final review result and key findings
- Copilot invocation evidence (`invoked: true|false`, tasks, agent ids, or reason not used)
- Boundary/constraint violations observed during run (if any)
- Suggested follow-up actions
