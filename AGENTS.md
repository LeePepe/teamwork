# Agents Index

This file is an index of all agents in the teamwork skill. Each agent is defined in `agents/<name>.md`. For repo conventions, style rules, commit guidelines, and versioning policy, see `CLAUDE.md`.

## Agent Inventory

| Agent | Role | May Edit Files? | Source Path | Purpose |
|-------|------|----------------|-------------|---------|
| `team-lead` | Orchestration | No | `agents/team-lead.md` | Pipeline orchestrator; delegates to all other agents |
| `research-lead` | Research | No | `agents/research-lead.md` | Splits scopes, routes backends, dispatches/merges researchers |
| `researcher` | Research | No | `agents/researcher.md` | Single-scope code/web research worker |
| `planner` | Planning | Plan files only | `agents/planner.md` | Creates structured plan files from research briefs |
| `plan-reviewer` | Planning | Plan files only | `agents/plan-reviewer.md` | Reviews and gates plan quality |
| `designer` | Design | Plan/design files only | `agents/designer.md` | Produces design plans for design-heavy tasks before execution |
| `codex-coder` | Execution | Yes | `agents/codex-coder.md` | Codex-backed executor for rigorous/heavy tasks |
| `copilot` | Execution | Yes | `agents/copilot.md` | Copilot-backed executor for all other tasks |
| `claude-coder` | Execution | Yes | `agents/claude-coder.md` | Claude-native fallback executor when plugins are unavailable |
| `verifier` | Quality | No | `agents/verifier.md` | Runs post-execution verification commands |
| `final-reviewer` | Quality | No | `agents/final-reviewer.md` | Final code review gate |
| `git-monitor` | Delivery | No | `agents/git-monitor.md` | Stages commits, creates PRs, monitors CI |

## Validation

Run `bash scripts/setup.sh --check` to verify agent installation status.
Run `bash scripts/setup.sh --repo` to install/sync agents to `.claude/agents/`.

## Commit Policy

Every time agents or commands are modified in this repo, finish both steps in the same task:
1. Create a commit (Conventional Commits style).
2. Push to `origin/<current-branch>` unless user explicitly says not to push.
