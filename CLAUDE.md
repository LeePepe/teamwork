# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## What This Repo Is

A teamwork skill (`SKILL.md`) plus agent prompts (`agents/`) implementing a governance-heavy pipeline:

`planner-lead -> plan gate (plan-reviewer+pm) -> execute -> verify -> pm delivery gate -> final-review coalition -> user-perspective -> ship`

## Commands

```
/teamwork:setup
/teamwork:setup --global
/teamwork:setup --check
```

CLI/Codex fallback:

```bash
bash scripts/setup.sh --repo
bash scripts/setup.sh --global
bash scripts/setup.sh --check
```

## Core Architecture

### Flow

```
SKILL.md -> team-lead -> planner-lead -> (plan-reviewer + pm) -> fullstack-engineer -> verifier -> pm -> final-reviewer -> user-perspective -> git-monitor
```

`planner-lead` internally dispatches:
- `researcher` (scoped research)
- `designer` (only when design output is required)
- `linter` (strict layer-dependency lint contract + CI gate requirements)

`final-reviewer` internally dispatches specialty reviewers:
- `security-reviewer`
- `devil-advocate`
- `a11y-reviewer`
- `perf-reviewer`
- `user-perspective`

### Agent Responsibilities

| Agent | Role | May modify project files? |
|-------|------|--------------------------|
| `team-lead` | Orchestrates entire pipeline | No |
| `planner-lead` | Unified planning owner (research + design coordination + plan output) | Plan/design files only |
| `linter` | Defines strict architecture lint rules and diagnostic contract | No |
| `researcher` | Scoped research worker | No |
| `designer` | Design artifact specialist (dispatched by planner-lead) | Plan/design files only |
| `plan-reviewer` | Technical plan gate | Plan files only |
| `pm` | Product plan gate + delivery supervision | No |
| `fullstack-engineer` | Unified executor (Copilot -> Claude fallback -> Codex tertiary) | Yes |
| `verifier` | Verification command runner and evidence provider | No |
| `final-reviewer` | Final code review + specialty coalition lead | No |
| `user-perspective` | Simulates real end-user usage after final review passes; provides structured feedback gate | No |
| `git-monitor` | Commit/PR/CI lifecycle | No |

## Governance Rules

- `plan-reviewer` and `pm` must both pass for plan approval.
- `verifier` evidence + `pm` delivery supervision gate execution readiness.
- Lint check is mandatory in verifier and CI gate.
- `final-reviewer` owns final consolidated verdict.
- Layered dependency baseline: `Types -> Config -> Repo -> Service -> Runtime -> UI`; lower layers cannot reverse-depend on upper layers.
- Any code-changing repair invalidates prior gate evidence.
- Automatic repair budget is bounded (single cycle unless user overrides).

## Pipeline Integrity

Managed by `scripts/pipeline-lib.sh`:
- plan hash verification
- write nonce verification
- repair budget enforcement
- oscillation detection
- persisted state (`.claude/pipeline-state.json`, never commit)

## Important Paths

- `agents/team-lead.md`
- `agents/planner-lead.md`
- `agents/plan-reviewer.md`
- `agents/pm.md`
- `agents/final-reviewer.md`
- `templates/flow-*.yaml`
- `templates/team.md`
- `scripts/pipeline-lib.sh`
- `scripts/setup.sh`

## File Conventions

- Agent files use YAML front matter (`name`, `description`, `tools`) + Markdown body.
- `tools` is a hard permission boundary.
- Use Conventional Commits (`type: short imperative summary`).
- After agent changes, run setup before validating installed copies.

## Completion Rule

When a requested change is complete and verification passes:
- Bump version using the policy in `docs/extending.md` (`SKILL.md` + `.claude-plugin/plugin.json`).
- Commit the changes with a Conventional Commit message.
- Push to the current remote branch.
