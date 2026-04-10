# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Claude Code skill (`SKILL.md`) plus agent definitions (`agents/`) that implement a structured **research → plan → review → execute → verify → final-review** pipeline. There is no compiled output — the "artifacts" are Markdown prompt files that get copied to `~/.claude/` or `.claude/`.

## Commands

```bash
# Syntax-check the setup script before committing changes to it
bash -n scripts/setup.sh

# Check current installation status (plugins, agents, skill file)
bash scripts/setup.sh --check

# Install globally
bash scripts/setup.sh --global

# Install into current git repo
bash scripts/setup.sh --repo
```

Always run `--check` before and after modifying setup logic to confirm idempotency.

## Architecture

### Pipeline Flow

```
SKILL.md  →  team-lead  →  researcher (1..N, parallel when independent)  →  planner  →  plan-reviewer  →  codex-coder / copilot / claude-coder  →  verifier  →  final-reviewer  →  git-monitor (optional)
```

`SKILL.md` is the skill entry point: it validates plugin availability, reads repo routing config (`.claude/team.md`), then delegates entirely to `team-lead`. The team-lead orchestrates the rest — it **must not modify files directly**.

### Basic Navigation Map

- Entry and orchestration:
  - `SKILL.md`
  - `commands/task.md`
  - `agents/team-lead.md`
- Research and planning:
  - `agents/researcher.md`
  - `agents/planner.md`
  - `agents/plan-reviewer.md`
- Execution and quality gates:
  - `agents/codex-coder.md`
  - `agents/copilot.md`
  - `agents/claude-coder.md`
  - `agents/verifier.md`
  - `agents/final-reviewer.md`
  - `agents/git-monitor.md`
- Install/runtime layout:
  - `scripts/setup.sh`
  - `.claude/skills/teamwork/SKILL.md` (installed copy)
  - `.claude/skills/teamwork/agents/*` (lazy-load source)

### Agent Responsibilities

| Agent | Role | May modify project files? |
|-------|------|--------------------------|
| `team-lead` | Orchestrates pipeline, routes tasks | No |
| `researcher` | Single-scope worker using Copilot; lead may run multiple in parallel and merge | No |
| `planner` | Writes plan files in `.claude/plan/` | Plan files only |
| `plan-reviewer` | Plan review/iteration (Codex when available, Claude fallback otherwise) | Plan files only |
| `codex-coder` | Executes strict/formal tasks (TS/JS, APIs, tests) | Yes |
| `copilot` | Executes all other tasks (Swift, scripts, UI) | Yes |
| `claude-coder` | Claude-native executor fallback when plugins are unavailable | Yes |
| `verifier` | Runs post-execution verification commands | No |
| `final-reviewer` | Runs final review on working tree (Codex when available, Claude fallback otherwise) | No |
| `git-monitor` | Stages commits, creates PRs, monitors CI and PR comments (optional, post-final-review) | No |

### Hard Pipeline Rule

`team-lead` has `tools: Read, Glob, Agent` — no write access. Any direct file change from the lead is a pipeline violation. File changes flow through executor agents (`codex-coder`, `copilot`, `claude-coder`).

### Executor Routing

Routing is determined by task weight/rigor (not file type) and can be overridden per-repo via `.claude/team.md`. Only two valid executor values: `codex` and `copilot`.

- `codex`: rigorous/heavy tasks — complex algorithms, security-sensitive, auth, data migrations, large refactors, critical business logic
- `copilot`: all other tasks — UI changes, simple features, scripts, config, docs, straightforward bug fixes

### Plugin Dependency

Executors delegate to plugins when available: `codex-coder` uses `codex-companion.mjs`, `copilot` uses `copilot-companion.mjs`. `researcher` can use either plugin and falls back to Claude-native research when needed. `team-lead` decides whether to run one or multiple researcher scopes and can parallelize independent scopes.

Fallback policy:
- `copilot=false` and `codex=true`: route all plugin-backed work to Codex
- `codex=false` and `copilot=true`: route research/execution to Copilot, use Claude-native review fallback
- `codex=false` and `copilot=false`: route all execution to `claude-coder`, and let lead choose Claude model

### Research and Verification Policies

- Code read/search requests should be routed to `researcher` first.
- `researcher` should output scoped area maps and split oversized areas into smaller sub-areas to reduce context.
- `verifier` may reuse cached verification only when cache key exactly matches current repo state + command set.

### Plan File Format

Plans are written to `.claude/plan/<slug>.md` with YAML frontmatter containing: `title`, `project` (absolute path), `branch`, `status: draft|approved`, `created`, `size: small|medium|large`, and a `tasks` list. Each task has `id`, `title`, `size`, `parallel_group`, `executor: codex|copilot`, and `status: pending|done`. Tasks in the same `parallel_group` are run in parallel; different groups run sequentially by dependency order.

### Source vs Installed Files

The repo ships two copies of agent prompts:
- `agents/*.md` — canonical source files (edit these)
- `.claude/agents/*.md` — installed copies for this repo (regenerated by `bash scripts/setup.sh --repo`)

Similarly, `SKILL.md` (source) installs to `.claude/skills/teamwork/SKILL.md`, and `commands/*.md` serve as the skill command handlers. The `templates/team.md` is the template copied to a new repo's `.claude/team.md` on first `--repo` install.

## File Conventions

- Agent files: YAML front matter (`name`, `description`, `tools`) then Markdown instructions
- The `tools:` field is a hard constraint — only list tools the agent is actually permitted to use
- `scripts/setup.sh` must keep `set -euo pipefail` and quote all variable expansions
- Conventional Commits format: `type: short imperative summary`
- When modifying agent behavior, update `agents/<name>.md` (source), then re-run `bash scripts/setup.sh --repo` to sync the installed `.claude/agents/` copies
