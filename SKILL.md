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

## Documentation Policy (hard rule for `feat`, warn for `fix|refactor`)

Code changes that introduce new user-visible behavior, agents, commands, or configuration MUST ship documentation updates in the SAME commit. This ensures docs never drift behind the implementation.

Scope:
- `feat` tasks: HARD — missing docs blocks the pipeline.
- `fix` and `refactor` tasks: WARN — final-reviewer flags but does not block.
- `perf`, `docs`, `chore`, `config` tasks: exempt.

"Docs" means repository-level markdown: `docs/*.md`, `AGENTS.md`, `ARCHITECTURE.md`, `README.md`, `CLAUDE.md`, command/skill descriptions. Inline code comments and JSDoc do not count.

Agent contracts:

- **`planner-lead`**: every `feat` task MUST carry a `docs: [...]` field. Plans that omit `docs` on a `feat` task FAIL plan validation.
- **`fullstack-engineer`**: for `feat` tasks, MUST update doc files in the same commit. Output includes `docs_updated: [paths]`.
- **`verifier`**: for `feat` tasks, missing doc files in the diff → `🔴 FAIL`. For `fix`/`refactor` → `docs_missing_warn=true` (non-blocking).
- **`final-reviewer`**: records `docs_updated: N`. Flags `fix`/`refactor` without doc updates as findings.
- **`git-monitor`**: for `feat` tasks, no doc files in staged diff → HARD FAIL.

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

## Workflow

1. Validate plugin readiness (Codex/Copilot optional).
2. Read `.claude/team.md` for routing/review/verification/model overrides.
3. Delegate immediately to `team-lead`.
4. `team-lead` runs plan-led pipeline and returns evidence.
5. Report outcome only; never implement directly in this skill entry.

## Hard Constraints

- Skill entry must not edit files.
- Always delegate to `team-lead` for real work.
- Require plan gate, verification, PM delivery gate, final-review gate, and user-perspective gate unless user explicitly overrides.
- Enforce bounded repair loops (single automatic repair budget).
- Re-run gates after any code-changing repair.
- Never commit `.claude/pipeline-state.json`.

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
