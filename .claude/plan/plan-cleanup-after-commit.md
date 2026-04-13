---
title: "Delete plan file after successful git commit"
project: /Users/tianpli/Development/planning-team-skill
branch: main
status: approved
created: 2026-04-13
size: small
tasks:
  - id: T1
    title: "Add plan-file deletion step to git-monitor.md (source)"
    size: small
    parallel_group: 1
    executor: codex
    status: done
  - id: T2
    title: "Update team-lead.md step 19 to mention plan-file deletion"
    size: small
    parallel_group: 1
    executor: codex
    status: done
  - id: T3
    title: "Bump version to 0.5.5 in SKILL.md and plugin.json"
    size: small
    parallel_group: 1
    executor: codex
    status: done
  - id: T4
    title: "Sync installed agent copies via setup.sh --repo"
    size: small
    parallel_group: 2
    executor: codex
    status: done
---

# Plan: Delete plan file after successful git commit

## Goal

After `git-monitor` successfully commits code and confirms all plan tasks have `status: done`, it should automatically delete the plan file to clean up the `.claude/plan/` directory.

## Tasks

### T1 — Add plan-file deletion step to git-monitor.md

File: `/Users/tianpli/Development/planning-team-skill/agents/git-monitor.md`

After step 3 (commit + push) and before step 5 (CI check), insert a new step 4:

**Step 4 — Delete plan file if all tasks are done**

```bash
# Count remaining pending tasks
PENDING_COUNT=$(grep -c 'status: pending' "<plan-path>" 2>/dev/null || echo "0")
if [ "$PENDING_COUNT" = "0" ]; then
  rm "<plan-path>"
  PLAN_DELETED=true
else
  PLAN_DELETED=false
fi
```

Also update the **Output Contract** section to add:
- `plan_deleted: true|false` — whether the plan file was deleted after commit

Add constraint: if plan deletion fails, log a warning but do not fail the overall result.

### T2 — Update team-lead.md step 19

File: `/Users/tianpli/Development/planning-team-skill/agents/team-lead.md`

In step 19, update the git-monitor bullet:
- Before: "`git-monitor` stages changes, commits, creates PR to base branch, and monitors CI/comments"
- After: "`git-monitor` stages changes, commits, creates PR to base branch, monitors CI/comments, and deletes the plan file when all tasks are done"

### T3 — Bump version to 0.5.5

Files:
- `/Users/tianpli/Development/planning-team-skill/skills/teamwork/SKILL.md`: change `version: "0.5.4"` → `version: "0.5.5"`
- `/Users/tianpli/Development/planning-team-skill/.claude-plugin/plugin.json`: change `"version": "0.5.4"` → `"version": "0.5.5"`

### T4 — Sync installed agent copies (depends on T1, T2)

Run:
```bash
bash /Users/tianpli/Development/planning-team-skill/scripts/setup.sh --repo
```

This propagates the edited `agents/git-monitor.md` and `agents/team-lead.md` to `.claude/agents/`.

## Verification

```bash
bash -n /Users/tianpli/Development/planning-team-skill/scripts/setup.sh
grep -q 'plan_deleted' /Users/tianpli/Development/planning-team-skill/agents/git-monitor.md
grep -q '0.5.5' /Users/tianpli/Development/planning-team-skill/skills/teamwork/SKILL.md
grep -q '0.5.5' /Users/tianpli/Development/planning-team-skill/.claude-plugin/plugin.json
diff /Users/tianpli/Development/planning-team-skill/agents/git-monitor.md /Users/tianpli/Development/planning-team-skill/.claude/agents/git-monitor.md
```
