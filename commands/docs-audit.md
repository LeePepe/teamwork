---
description: Scan the repository for documentation-code drift and auto-fix findings via team-lead delegation.
argument-hint: "[--category agent_inventory|skill_pipeline|docs_content|readme|command_docs|template_config|cross_file] [--dry-run]"
allowed-tools: Bash, Agent
---

If `${ARGUMENTS}` contains `--help`, return:
> `/teamwork:docs-audit` — scan for doc-code drift and auto-fix
> Options:
>   `--dry-run` — report only, do not fix
>   `--category <cat>` — limit scan to one drift category
>   (no args) — full scan + auto-fix critical/high findings

## Step 1 — Parse Arguments

```bash
DRY_RUN=false
CATEGORY=""
PREV=""
for arg in ${ARGUMENTS}; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --category) PREV="category" ;;
    *)
      if [ "$PREV" = "category" ]; then
        CATEGORY="$arg"
        PREV=""
      fi
      ;;
  esac
done
echo "dry_run=$DRY_RUN category=${CATEGORY:-all}"
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

## Step 4 — Auto-fix or Report

If the report has critical or high findings AND `DRY_RUN=false`:
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
- Medium and low findings: list in plan as deferred follow-ups.
- Commit message prefix: `docs: fix drift —`
```

- Wait for `team-lead` completion.
- Return combined summary: N findings fixed, M deferred.

If the report has NO critical/high findings:
- Return: `No critical or high drift findings. N medium/low items noted.`

If `DRY_RUN=true`:
- Return the drift report directly without fixing.

## Step 5 — Cleanup

If Step 2 had `temp=true`, run `rm -f "<path>"`.
