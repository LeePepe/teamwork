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
  │     ├── perf-reviewer
  │     └── user-perspective
  └── git-monitor    → optional commit/PR/CI monitoring
```

## Stage Model

Default (`standard`):

```
plan -> plan-review -> execute -> verify -> pm-review -> final-review -> ship
```

Gate policy:
- Plan gate passes only when `plan-reviewer` and `pm(plan-gate)` are both pass.
- Delivery gate uses `verifier` evidence plus `pm(delivery-gate)` supervision.
- Final gate is owned by `final-reviewer` consolidated verdict.

## Workflow

1. Validate plugin readiness (Codex/Copilot optional).
2. Read `.claude/team.md` for routing/review/verification/model overrides.
3. Delegate immediately to `team-lead`.
4. `team-lead` runs plan-led pipeline and returns evidence.
5. Report outcome only; never implement directly in this skill entry.

## Hard Constraints

- Skill entry must not edit files.
- Always delegate to `team-lead` for real work.
- Require plan gate, verification, PM delivery gate, and final-review gate unless user explicitly overrides.
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
