---
name: teamwork-retro
description: Use when auditing a completed teamwork run and you need log-grounded per-agent role/model/tool/skill evidence plus compliance gaps against current teamwork rules.
allowed-tools: Bash, Read
---

# Teamwork Retro

Run a structured retrospective from execution logs and output a complete per-agent ledger **using the mandatory retro template below**.

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
3. Populate the **Mandatory Retro Template** (below) with evidence from the logs.
4. If fields are missing, explicitly mark `unknown` and list them under `Missing evidence`.

## Mandatory Retro Template (ALL sections required)

Every retro output MUST contain every section. Omitting a section is a compliance violation; missing *evidence* inside a section must be recorded as `unknown` or `n/a`, never silently dropped.

```markdown
# Teamwork Retro — <run-id>

**Date:** YYYY-MM-DD
**Repo:** <absolute path>
**Branch:** <branch>  (base: <base-branch>, shared: true|false)
**Commits:** <sha1>, <sha2>, ...
**Teamwork version:** <x.y.z>
**Harness mode:** standard | degraded-single-operator | degraded-no-subagent
**Outcome:** pass | fail | iterate | interrupted

## 1. Pipeline compliance table

| Stage | Agent (handle) | Model | Tools | Skills | Status | Evidence |
|-------|----------------|-------|-------|--------|--------|----------|
| planner-lead       | ... | ... | ... | ... | pass/iterate/fail/skipped/unknown | spawn/wait/result refs |
| plan-reviewer      | ... |     |     |     | ... | ... |
| pm(plan-gate)      | ... |     |     |     | ... | ... |
| fullstack-engineer | ... |     |     |     | ... | ... |
| verifier           | ... |     |     |     | ... | ... |
| pm(delivery-gate)  | ... |     |     |     | ... | ... |
| final-reviewer     | ... |     |     |     | ... | ... |
| user-perspective   | ... |     |     |     | ... | ... |
| git-monitor        | ... |     |     |     | ... | ... |

Any `skipped` stage MUST include the reason and whether it was an authorized override.

## 2. Files changed

- New: N files (list or summary)
- Modified: N files
- Deleted: N files
- Total: +X / -Y lines

## 3. Commits / PRs

- Commit SHAs with one-line conventional-commit titles
- PR URL(s) or explicit reason PR was not created (with link to guardrail decision)
- Branch strategy: feature-branch+PR | direct-push-to-base (must match shared-branch guardrail)

## 4. Verification evidence

- Test suite results (N passed / M failed / skipped)
- Build output summary
- Lint results (required — note if not run)
- Any smoke tests or dry-runs
- Link / path to raw logs when available

## 5. Deviations / degraded modes

Required even when none. Typical entries:
- `harness_mode != standard` — describe what gates/steps ran inline and why.
- Inline stage execution (any violation of "Never execute pipeline stages inline").
- Waived hard rules (which, by whom, recorded where).
- Direct push to a shared base branch (authorized? PR still opened?).
- Missing remote when `PR_REQUIRED=true`.

If no deviations: write `None`.

## 6. Unresolved follow-ups

Structured list — each item:

```yaml
- title: <short imperative>
  severity: critical|high|medium|low
  owner: <person|agent|unassigned>
  ref: <issue/PR URL or "none">
  notes: <optional>
```

## 7. Skill-improvement proposals

Concrete, actionable changes to the teamwork/teamwork-retro skill or agent prompts themselves that would have prevented issues seen in this run. Each item:

```yaml
- target: teamwork SKILL.md | teamwork-retro SKILL.md | agents/<name>.md | scripts/<x>
  change: <what to change>
  severity: critical|high|medium|low
  theme: <cross-cutting theme or local>
```

## 8. Missing evidence

Table of stages/fields where model/tools/skills/evidence were unknown and what the operator should capture next run.

| Stage | Field | Reason unknown | Fix |
|-------|-------|----------------|-----|
```

## Nested-harness / degraded-mode flagging

Retros MUST explicitly set `Harness mode` in the template header. Detection cues:
- Run log contains `harness_mode: degraded-*` — copy it verbatim.
- No `Agent` tool was available to the invoking agent — infer `degraded-no-subagent`.
- Stages executed inline by a single operator with the "no direct edits" rule waived — `degraded-single-operator`.

A degraded-mode run is not automatically a failure, but the retro MUST:
1. List every rule that was waived.
2. Record whether an explicit user override was granted.
3. Surface a skill-improvement proposal under section 7 (unless the harness limitation is already tracked).

## Hard Constraints

- Retrospective must be evidence-based (only from provided logs).
- Do not infer gate pass/fail without explicit log traces.
- Always report missing evidence as a finding, not as success.
- All 8 template sections are mandatory. Omitting one is a compliance violation.
- Harness mode MUST be declared in the header.
