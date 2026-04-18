# Five-Repo Teamwork Run — Consolidated Retro Findings

**Date:** 2026-04-18
**Teamwork version:** 0.16.1
**Runs ingested:** A-agent-ops, B-financial, C-monitorself, D-soe, E-loki
**Source retros:** `/tmp/teamlead-run/{A,B,C,D,E}-*.retro.md`

## Per-retro summary

### A — agent-ops-dashboard (DEGRADED — single-operator mode)
- **Mode:** Nested `team-lead` invocation under `claude -p` could **not** dispatch sub-agents; pipeline collapsed into a single-operator run with the "no direct edits" rule waived per user authorization.
- **Delivered:** `hermes-watchdog` agent (390 LOC, 16 unit tests) + lokikit telemetry across backend (FastAPI middleware, batch ingress) and frontend (`BrowserTelemetry`, sendBeacon).
- **Verification:** 31/31 unit tests; vite build clean; secret scan clean.
- **Git:** Created remote `LeePepe/agent-ops-dashboard`, pushed directly to `main` (no branch + no PR).
- **Notable risk:** Untracked working tree imports referenced by new commits (`backend/app/...`); `pytest.mark.unit` unregistered.

### B — Financial
- **Mode:** Standard pipeline executed inline (research-lead → planner → reviewers → executors → verifier → final-reviewer).
- **Delivered:** Backend lokikit telemetry (zero new deps), frontend dynamic-import wrapper, `financial-analyzer` agent, `financial-preferences` skill.
- **Verification:** 14/14 backend pytest, frontend `npm run build` + `tsc --noEmit` clean.
- **Git:** Two feature commits on `feat/lokikit-integration`; **no remote configured → push & PR silently skipped**.
- **Notable risk:** Placeholder allocation/budget values committed; SDK still requires manual `npm install`.

### C — MonitorSelf
- **Mode:** Inline pipeline; backend executed via codex-coder, frontend via fullstack-engineer.
- **Delivered:** Lokikit telemetry both stacks, additive SQLite migration for `owner_type`, personal-repo tracking, cross-repo prompt aggregator agent + `Insights` route.
- **Verification:** 14/14 pytest, vite build clean, `from main import app` OK (21 routes).
- **Git:** Single commit `8a8c990` on `main`; **no remote → push & PR skipped**.
- **Notable risk:** PII (`tianpli@microsoft.com`) baked into aggregator defaults; Pydantic v2 deprecation; `print()` not caught until final review (no PostToolUse lint hook ran).

### D — soe / MacMetric
- **Mode:** Inline pipeline; SwiftPM target.
- **Delivered:** LokiKit + MacMetric integration on `feat/lokikit-telemetry` (commit `7580ca7`); two-stream design (`performance` + `user_action`); 7 new tests (36/36 total pass).
- **Verification:** `swift build` ✅, `swift test` ✅.
- **Git:** Feature branch exists locally; **no remote configured → push & PR skipped**.

### E — loki-telemetry-stack
- **Mode:** Inline pipeline. Cleanly executed all stages.
- **Delivered:** `project-analyzer` agent (12 files, 1315 LOC, 8 tests, distinct exit codes 0/2/3/4).
- **Verification:** 8/8 pytest, dry-run reports for all 4 projects.
- **Git:** Single commit on `feat/project-analyzer-agent` → pushed `-u` → **PR #1 opened to upstream `main`** (only run that respected shared-branch policy because remote existed AND user had explicitly noted main is shared).

## Cross-cutting themes

### Theme 1 — Nested-harness sub-agent collapse (CRITICAL)
A `team-lead` spawned inside a non-interactive harness (`claude -p`, stdin pipe, CI runner without Agent tool) cannot dispatch sub-agents. Today the pipeline silently collapses into single-operator inline execution, **violating the "Never execute pipeline stages inline" hard rule**. Run A explicitly hit this. The current SKILL/team-lead has no preflight detection and no documented degraded-path contract.

**Impact:** Loss of plan/delivery/final gates; silent waiver of "no direct edits" rule.

### Theme 2 — Shared-branch / direct-push to main (CRITICAL)
3 of 5 runs landed code directly on `main` (A: pushed; C, B: committed locally). Only E opened a PR — and only because `loki-telemetry-stack` was explicitly tagged shared. The current `git-monitor` workflow assumes branch ≠ base, but team-lead does not enforce branch creation when the current branch *is* the base/shared branch.

**User preference (stated):** branch + PR over direct push, especially on shared/protected branches.

### Theme 3 — Silent skip when no git remote (HIGH)
4 of 5 runs ended with "no remote → PR skipped" as a soft note. `git-monitor` step 6 currently sets `pr_url: null` and adds a note, returning `result: ok`. When the plan **promised** a PR, this is a delivery-gate violation, not a benign skip. PM did not catch it.

**Impact:** Operators believe ship is complete; nothing is reviewable upstream.

### Theme 4 — Inconsistent retro depth & structure (MEDIUM)
The five retros vary widely:
- A is execution-only with no pipeline-stage table.
- B has a full pipeline-stage table.
- C has stages + Highs auto-fixed list + files-changed summary.
- D has tracks/troubles narrative, no compliance table.
- E has a clean pipeline-stage table + improvements/follow-ups.

There is no MANDATORY template in the `teamwork-retro` skill; comparing across runs is manual stitching. Cross-run analytics (this very document) was harder than necessary.

### Theme 5 — Lint/format coverage gaps (LOW)
C noted that final-reviewer caught `print()` calls a linter should have caught earlier. No PostToolUse lint hook ran. Linter contract enforcement is plan-stage only; runtime enforcement is missing in the executor loop.

### Theme 6 — Underspecified follow-ups (LOW)
Several retros end with vague TODOs (PII removal, threshold overrides, commit-ingestion). No standard "Unresolved follow-ups" structured field means these never make it back into a plan.

## Actionable skill-change proposals

| # | Theme | Skill | Change | Severity |
|---|------|-------|--------|----------|
| P1 | Theme 1 | `teamwork` SKILL.md + team-lead | Add **Nested-harness preflight**: detect missing Agent tool / `claude -p` stdin / non-TTY; if true, emit loud `DEGRADED_HARNESS` notice, halt by default, require explicit `--allow-degraded` to proceed via documented single-operator path | CRITICAL |
| P2 | Theme 2 | `teamwork` SKILL.md + team-lead + git-monitor | Add **Shared-branch guardrail**: if `current_branch ∈ {main, master, default-branch, $PROTECTED_BRANCHES}`, team-lead MUST instruct git-monitor to create a feature branch before any execution that produces commits; never direct-push to a shared base | CRITICAL |
| P3 | Theme 3 | `teamwork` SKILL.md + git-monitor | **Remote-required operations**: if plan declares PR creation OR `team.md` requires upstream review, missing `git remote` is a `result: fail`, not `result: ok with note` | HIGH |
| P4 | Theme 4 | `teamwork-retro` SKILL.md | Standardize MANDATORY retro template: Pipeline compliance table, Files changed, Commits/PRs, Verification evidence, Deviations / degraded-modes, Unresolved follow-ups, Skill-improvement proposals | MEDIUM |
| P5 | Theme 4 | `teamwork-retro` SKILL.md | Add explicit **degraded-mode flag** field — every retro must declare `harness_mode: standard|degraded-single-operator|degraded-no-subagent` | MEDIUM |
| P6 | Theme 5 | (future) `verifier` / linter | Add post-edit lint hook spec — out of scope for this PR (tracked as follow-up) | LOW |
| P7 | Theme 6 | `teamwork-retro` | Mandate structured `unresolved_followups[]` items with `{title, owner, severity, ref_to_issue?}` so they round-trip back into planning | LOW |

## Out of scope for this PR
- P6 (lint hooks) — requires verifier-side changes plus per-language config; defer.
- E2E live-Loki integration test (E) — repo-specific.
- PII/env-var hygiene per-repo (C).
