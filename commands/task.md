---
description: Run a task through the full research → plan → review → execute → verify → final-review pipeline. Pass your task description as the argument.
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
[ -n "$CODEX_SCRIPT" ]   && node "$CODEX_SCRIPT"   setup --json 2>/dev/null && CODEX_OK=true || true
[ -n "$COPILOT_SCRIPT" ] && node "$COPILOT_SCRIPT" setup --json 2>/dev/null && COPILOT_OK=true || true

echo "codex=$CODEX_OK copilot=$COPILOT_OK"
```

Do not stop when both are false; `team-lead` will use Claude-native fallback.

## Step 2 — Read team config

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$REPO_ROOT" ] && cat "$REPO_ROOT/.claude/team.md" 2>/dev/null || echo "(no team.md)"
```

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
```

## Step 4 — Report outcome

Return:
- Research split strategy and consolidated result summary (or `research_unavailable`)
- Fallback strategy and selected model (when Claude fallback is used)
- Plan file path
- Modified files grouped by executor
- Failed or skipped tasks
- Verification result and command evidence
- Final review result and key findings
- Suggested follow-up actions
