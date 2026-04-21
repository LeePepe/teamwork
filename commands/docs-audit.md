---
description: Scan the repository for documentation-code drift and produce a structured report with actionable fix suggestions.
argument-hint: "[--fix] [--category agent_inventory|skill_pipeline|docs_content|readme|command_docs|template_config|cross_file]"
allowed-tools: Bash, Agent
---

If `${ARGUMENTS}` contains `--help`, return:
> `/teamwork:docs-audit` — scan for doc-code drift
> Options:
>   `--fix` — after audit, spawn team-lead to fix critical+high findings
>   `--category <cat>` — limit scan to one drift category
>   (no args) — full scan, report only

## Step 1 — Parse Arguments

```bash
FIX_MODE=false
CATEGORY=""
for arg in ${ARGUMENTS}; do
  case "$arg" in
    --fix) FIX_MODE=true ;;
    --category) : ;; # next arg is the value
    agent_inventory|skill_pipeline|docs_content|readme|command_docs|template_config|cross_file)
      CATEGORY="$arg" ;;
  esac
done
echo "fix=$FIX_MODE category=${CATEGORY:-all}"
```

## Step 2 — Ensure docs-auditor Agent Exists

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
TARGET="${REPO_ROOT:-$HOME}/.claude/agents"
AUDITOR_PATH="$TARGET/docs-auditor.md"
AUDITOR_TEMP=false

mkdir -p "$TARGET"

if [ ! -f "$AUDITOR_PATH" ]; then
  for src in \
    "$REPO_ROOT/.claude/skills/teamwork/agents/docs-auditor.md" \
    "$HOME/.claude/skills/teamwork/agents/docs-auditor.md" \
    "${CLAUDE_PLUGIN_ROOT}/agents/docs-auditor.md"
  do
    if [ -n "$src" ] && [ -f "$src" ]; then
      cp "$src" "$AUDITOR_PATH"
      AUDITOR_TEMP=true
      break
    fi
  done
fi

[ -f "$AUDITOR_PATH" ] || { echo "docs_auditor=missing"; exit 1; }
echo "docs_auditor=ok path=$AUDITOR_PATH temp=$AUDITOR_TEMP"
```

If `docs_auditor=missing`, stop and ask user to run `/teamwork:setup`.

## Step 3 — Spawn docs-auditor

Spawn `docs-auditor` with:

```
Scan this repository for documentation-code drift.
Category filter: ${CATEGORY:-all categories}
Return a structured drift report per your output contract.
```

Wait for completion. Capture the drift report.

## Step 4 — Report or Fix

If `FIX_MODE=false`:
- Return the drift report directly to the user.
- Include a summary line: `Run /teamwork:docs-audit --fix to auto-fix critical and high findings.`

If `FIX_MODE=true` AND the report has critical or high findings:
- Ensure `team-lead` exists (same as task.md Step 2.5).
- Spawn `team-lead` with:

```
Task: Fix documentation-code drift findings from docs-audit.

Drift report:
<paste the docs-auditor report>

Instructions:
- Create plan tasks ONLY for critical and high severity findings.
- Each task type is `docs` (exempt from unit-test requirement).
- Do not change code behavior — only update documentation to match current code.
- Skip medium and low findings (report them as deferred).
```

- Wait for `team-lead` completion.
- Return the combined audit + fix report.

If `FIX_MODE=true` AND no critical/high findings:
- Return: `No critical or high drift findings. N medium/low items deferred.`

## Step 5 — Cleanup

If Step 2 had `temp=true`, run `rm -f "<path>"`.
