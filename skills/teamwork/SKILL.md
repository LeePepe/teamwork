---
name: teamwork
description: Use for explicit teamwork orchestration requests (/teamwork:task, /teamwork:mapping-repo, or "use teamwork"). Delegates to team-lead for plan-led execution with gated review and verification.
allowed-tools: Bash, Agent
---

# Teamwork Skill

Run a structured multi-agent pipeline where `team-lead` orchestrates all stages and delegates implementation to specialist agents.

## Triggers

```text
/teamwork:task <description>
/teamwork:mapping-repo
/teamwork:mapping-repo --update
```

Natural language trigger:

```text
Use teamwork to implement <feature>
```

## Setup / Check

- Claude slash command: `/teamwork:setup`
- CLI/Codex fallback: `bash scripts/setup.sh --repo` / `bash scripts/setup.sh --check`

## Unit-test Policy (hard rule)

Every plan task that adds or modifies executable code MUST ship tests in the SAME commit. This is a non-negotiable pipeline integrity rule. Enforcement is layered across five agents so that no single failure point can leak.

Scope:
- Task types `docs`, `chore`, and `config` are exempt.
- All other tasks (`feat`, `fix`, `refactor`, `perf`) require at least one unit-test file added or modified alongside the code change.

Agent contracts:

- **`planner-lead`**: every code task in the plan MUST carry a `tests: [...]` field enumerating the test files that will ship with the code. Plans that omit `tests` on a code task FAIL plan validation.
- **`fullstack-engineer`**: MUST self-fail with `status: fail, reason: ut-required` when `tests_added` is empty for a non-exempt task. Do NOT hand off to verifier to catch missing tests. Tests ship with code in the SAME commit — never defer tests to a later task. Output contract MUST include `tests_added: [paths]` and `tests_run: {passed, failed, skipped}`.
- **`verifier`**: MUST fail the delivery gate when the diff shows new/modified source files with zero test counterparts in the same commit (task type override: `docs|chore|config`). A matching test counterpart is any file under `tests/`, or `*_test.*`, `*.test.*`, `test_*`.
- **`final-reviewer`**: MUST record `tests_added: N, tests_modified: M` in the consolidated summary line.
- **`git-monitor`**: pre-push check. If staged diff contains code changes and zero test files AND the task type is not exempt, refuse to push with `result: fail, reason: ut-missing-for-code-change`.

Rationale: moving the UT check left (planner and executor) means failures surface in minutes, not at the final gate. Moving it right (verifier, final-reviewer, git-monitor) means defense-in-depth for the cases where earlier layers are bypassed.

## Documentation Policy (hard rule for `feat`, warn for `fix|refactor`)

Code changes that introduce new user-visible behavior, agents, commands, or configuration MUST ship documentation updates in the SAME commit. This ensures docs never drift behind the implementation.

Scope:
- `feat` tasks: HARD — missing docs blocks the pipeline.
- `fix` and `refactor` tasks: WARN — final-reviewer flags but does not block.
- `perf`, `docs`, `chore`, `config` tasks: exempt.

"Docs" means repository-level markdown: `docs/*.md`, `AGENTS.md`, `ARCHITECTURE.md`, `README.md`, `CLAUDE.md`, command/skill descriptions. Inline code comments and JSDoc do not count.

Agent contracts:

- **`planner-lead`**: every `feat` task in the plan MUST carry a `docs: [<doc-file-path>, ...]` field listing the documentation files to be created or updated. Plans that omit `docs` on a `feat` task FAIL plan validation. `fix`/`refactor` tasks SHOULD include `docs` when behavior changes are user-visible, but omission is a warning, not a block.
- **`fullstack-engineer`**: for `feat` tasks, MUST update the listed doc files in the same commit as the code. If docs cannot be written, return `status: fail, reason: docs-required`. Output contract MUST include `docs_updated: [paths]` (may be empty ONLY for exempt types).
- **`verifier`**: for completed `feat` tasks, check that at least one doc file (`docs/*.md`, `AGENTS.md`, `ARCHITECTURE.md`, `README.md`, `CLAUDE.md`) is in the diff. If missing, return `🔴 FAIL` with `docs_missing=true`. For `fix`/`refactor` tasks with no doc changes, emit `docs_missing_warn=true` (non-blocking).
- **`final-reviewer`**: record `docs_updated: N` in the consolidated summary. Flag `fix`/`refactor` tasks that changed user-visible behavior without doc updates as review findings.
- **`git-monitor`**: for `feat` tasks, if staged diff contains no doc files, HARD FAIL with `result: fail, reason: docs-missing-for-feat`. Reference the Documentation Policy in `notes`.

## Pipeline

```text
team-lead
  ├── planner-lead      → dispatches researcher/designer/linter, writes plan
  │     ├── researcher(s) (parallel when useful)
  │     └── designer (only when design output required)
  │     └── linter (layered dependency lint contract)
  ├── plan-reviewer  → technical plan gate
  ├── pm             → product plan gate + delivery supervision
  ├── fullstack-engineer → execute tasks
  ├── verifier       → command-level verification evidence
  ├── final-reviewer → code review + specialty review coalition
  │     ├── security-reviewer
  │     ├── devil-advocate
  │     ├── a11y-reviewer
  │     └── perf-reviewer
  ├── user-perspective → mandatory real UX testing gate (Playwright/XCUITest)
  └── git-monitor    → commit/PR/CI monitoring (only after user-perspective passes)
```

## Stage Model

Default (`standard`):

```
plan -> plan-review -> execute -> verify -> pm-review -> final-review -> user-perspective -> ship
```

Gate policy:
- Plan gate passes only when `plan-reviewer` and `pm(plan-gate)` are both pass.
- Delivery gate uses `verifier` evidence plus `pm(delivery-gate)` supervision.
- Final gate is owned by `final-reviewer` consolidated verdict.
- **User-perspective gate** (mandatory — non-skippable): real automated UX testing via Playwright (web) or XCUITest/apple-ui-tester (iOS/macOS). `git-monitor` is blocked until this gate passes. If 🟡 ITERATE, `fullstack-engineer` repairs and the gate re-runs. If 🔴 FAIL, pipeline halts.

## Preflight Guardrails (Mandatory)

Team-lead MUST run these preflight checks before starting planning. Each failed check halts the pipeline unless the user provides an explicit override recorded in `.claude/pipeline-state.json`.

### 1. Nested-harness / subagent-availability check

Sub-agent dispatch fails silently when `team-lead` is invoked inside a non-interactive harness (e.g. `claude -p` with piped stdin, CI runners without the Agent tool, or nested spawn contexts where the inner invocation loses tool permissions). Left undetected, the pipeline collapses into single-operator inline execution and violates the "Never execute pipeline stages inline" hard rule.

Detection (team-lead, at pipeline start):

```bash
# Heuristics — any one triggering means degraded mode likely
NESTED_HARNESS=false
[ ! -t 0 ]                          && NESTED_HARNESS=true    # non-TTY stdin (claude -p pipe)
[ -n "$CLAUDE_P_NONINTERACTIVE" ]   && NESTED_HARNESS=true    # explicit flag
[ -n "$CI" ]                        && NESTED_HARNESS=true    # CI runner
# Tool availability probe — if the running agent cannot see "Agent" in its
# granted tool list, it cannot spawn sub-agents.
case ",$ALLOWED_TOOLS," in *,Agent,*) : ;; *) NESTED_HARNESS=true ;; esac
```

Required response:
- **Default:** emit a loud `DEGRADED_HARNESS` notice to the final output and **halt**. Do not start planning. Return `result: fail, reason: nested-harness-detected`.
- **User override:** only proceed when the user (or the invoking command) explicitly passes `allow_degraded: single-operator` in the task input. In that case, record the override in pipeline state, annotate every stage in the execution ledger with `harness_mode: degraded-single-operator`, and follow the documented degraded path (see below).
- The final response and the persisted run log MUST include `harness_mode` so `teamwork-retro` can flag the run.

Documented degraded single-operator path (only when user override granted):
- Hard rules "Never edit project files" and "Never execute pipeline stages inline" are **explicitly waived for this run only**.
- Every normally-spawned stage becomes an inline checklist item; the operator must still produce the same evidence the stage would have produced (plan artefact, verifier command output, etc.).
- Gate decisions must be captured as explicit self-reviews against the same criteria; never mark a gate "pass" without recording the evidence inline.

### 2. Shared-branch guardrail

If the repo's current branch is the shared base (`main`, `master`, the detected default branch, or any branch listed in `PROTECTED_BRANCHES` / `team.md`), team-lead MUST NOT run execution stages that produce commits on that branch. Required action:

```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHARED_SET="main master $BASE_BRANCH ${PROTECTED_BRANCHES:-}"
case " $SHARED_SET " in *" $CURRENT_BRANCH "*) SHARED=true ;; *) SHARED=false ;; esac
```

- If `SHARED=true`: instruct `fullstack-engineer` / `git-monitor` to **create a feature branch** (`<type>/<plan-slug>`) before any commit, and **never direct-push** to the shared base. The plan MUST declare branch+PR as the shipping mechanism.
- A direct push to a shared base by any agent is a pipeline integrity violation, even when no remote protection rule exists locally.
- User override: accept `allow_shared_branch_push: true` only when explicitly set in task input; record in state.

### 3. Remote-required operations

When the plan declares PR creation, or `team.md` requires upstream review, the absence of a git remote is a hard failure, not a silent skip.

`git-monitor` contract:

```bash
HAS_REMOTE=$(git remote 2>/dev/null | head -1)
if [ -z "$HAS_REMOTE" ] && [ "$PR_REQUIRED" = "true" ]; then
  # FAIL — do not return ok
  echo "result: fail, reason: remote-required-but-missing"
  exit 1
fi
```

- `PR_REQUIRED` is derived from the plan (explicit `ship: pr`) OR from shared-branch guardrail (Theme 2) OR from `.claude/team.md` review mode.
- When `PR_REQUIRED=false` (e.g. solo repo, local-only ship), `git-monitor` may return `result: ok, pr_url: null, notes: "no remote configured; PR not required"`.
- PM's delivery gate MUST reject a run whose plan required a PR but `git-monitor` returned no `pr_url`.

## Workflow

1. Validate plugin readiness (Codex/Copilot optional).
2. Read `.claude/team.md` for routing/review/verification/model overrides.
3. **Run Preflight Guardrails** (nested-harness, shared-branch, remote-required).
4. Delegate immediately to `team-lead`.
5. `team-lead` runs plan-led pipeline and returns evidence.
6. Report outcome only; never implement directly in this skill entry.

## Hard Constraints

- Skill entry must not edit files.
- Always delegate to `team-lead` for real work.
- Do not run independent post-delegation verification in the entry handler.
- Require plan gate, verification, PM delivery gate, final-review gate, and user-perspective gate unless user explicitly overrides.
- Enforce bounded repair loops (single automatic repair budget).
- Re-run gates after any code-changing repair.
- Require `team-lead` final output to include stage-level execution ledger with `role/model/tools/skills/status/evidence`.
- Never commit `.claude/pipeline-state.json`.
- Final output MUST include `harness_mode` (`standard|degraded-single-operator|degraded-no-subagent`).
- Never direct-push to a shared base branch; always branch+PR unless explicit user override is recorded.
- `PR_REQUIRED` plans with no git remote are a git-monitor failure, not a silent skip.

## Shipped Agents

- `team-lead.md`
- `planner-lead.md`
- `linter.md`
- `researcher.md`
- `designer.md`
- `plan-reviewer.md`
- `pm.md`
- `fullstack-engineer.md`
- `verifier.md`
- `final-reviewer.md`
- `git-monitor.md`
- `security-reviewer.md`
- `devil-advocate.md`
- `a11y-reviewer.md`
- `perf-reviewer.md`
- `user-perspective.md`
- `docs-auditor.md`
