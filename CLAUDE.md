# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Claude Code skill (`SKILL.md`) plus agent definitions (`agents/`) that implement a structured **research → plan → review → design (when needed) → execute → verify → final-review** pipeline. There is no compiled output — the "artifacts" are Markdown prompt files that get copied to `~/.claude/` or `.claude/`.

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
SKILL.md  →  team-lead  →  research-lead  →  researcher (1..N, parallel when independent)  →  planner  →  plan-reviewer  →  designer (when needed)  →  fullstack-engineer  →  verifier  →  final-reviewer  →  git-monitor (optional)
```

`SKILL.md` is the skill entry point: it validates plugin availability, reads repo routing config (`.claude/team.md`), then delegates entirely to `team-lead`. The team-lead orchestrates the rest — it **must not modify files directly**.

### Basic Navigation Map

- Entry and orchestration:
  - `SKILL.md`
  - `commands/task.md`
  - `agents/team-lead.md`
- Research and planning:
  - `agents/research-lead.md`
  - `agents/researcher.md`
  - `agents/planner.md`
  - `agents/plan-reviewer.md`
  - `agents/designer.md`
- Execution and quality gates:
  - `agents/fullstack-engineer.md`
  - `agents/verifier.md`
  - `agents/final-reviewer.md`
  - `agents/git-monitor.md`
- Install/runtime layout:
  - `scripts/setup.sh`
  - `.claude/skills/teamwork/SKILL.md` (installed copy)
  - `.claude/skills/teamwork/agents/*` (lazy-load source)

- Pipeline infrastructure:
  - `scripts/pipeline-lib.sh`
- Flow templates:
  - `templates/flow-standard.yaml`
  - `templates/flow-review.yaml`
  - `templates/flow-build-verify.yaml`
  - `templates/flow-pre-release.yaml`
- Testing:
  - `test/test-pipeline.sh`
- Specialty reviewers:
  - `agents/pm.md`
  - `agents/security-reviewer.md`
  - `agents/devil-advocate.md`
  - `agents/a11y-reviewer.md`
  - `agents/perf-reviewer.md`
  - `agents/user-perspective.md`

### Agent Responsibilities

| Agent | Role | May modify project files? |
|-------|------|--------------------------|
| `team-lead` | Orchestrates pipeline, routes tasks | No |
| `research-lead` | Splits research scopes, dispatches researchers, consolidates brief for planner | No |
| `researcher` | Single-scope worker dispatched by research-lead | No |
| `planner` | Writes plan files in `.claude/plan/` | Plan files only |
| `plan-reviewer` | Plan review/iteration (Codex when available, Claude fallback otherwise) | Plan files only |
| `designer` | Creates design plan artifacts for design-heavy tasks before coding | Plan/design files only |
| `fullstack-engineer` | Unified executor — Codex → Copilot → Claude-native fallback | Yes |
| `verifier` | Runs post-execution verification commands | No |
| `final-reviewer` | Runs final review on working tree (Codex when available, Claude fallback otherwise) | No |
| `git-monitor` | Stages commits, creates PRs, monitors CI and PR comments (optional, post-final-review) | No |
| `pm` | Advisory | No | `agents/pm.md` | Product manager perspective; user value and scope validation |
| `security-reviewer` | Quality | No | `agents/security-reviewer.md` | Security-focused review; vulnerability identification |
| `devil-advocate` | Advisory | No | `agents/devil-advocate.md` | Adversarial challenger; stress-tests assumptions |
| `a11y-reviewer` | Quality | No | `agents/a11y-reviewer.md` | Accessibility review; WCAG compliance |
| `perf-reviewer` | Quality | No | `agents/perf-reviewer.md` | Performance review; bottleneck identification |
| `user-perspective` | Advisory | No | `agents/user-perspective.md` | End-user perspective; UX quality evaluation |

### Hard Pipeline Rule

`team-lead` has `tools: Read, Glob, Agent` — no write access. Any direct file change from the lead is a pipeline violation. File changes flow through the executor agent (`fullstack-engineer`).

### Executor Routing

Routing is determined by task weight/rigor (not file type) and can be overridden per-repo via `.claude/team.md`. Only two valid executor values: `codex` and `copilot`.

- `codex`: rigorous or heavy tasks (complex algorithms, security-sensitive code, auth/authz, data migrations, strict correctness requirements, large-scale refactors, critical business logic, tasks needing deep analysis)
- `copilot`: all other tasks (UI changes, simple features, scripts, config, docs, straightforward bug fixes)

### Plugin Dependency

`fullstack-engineer` delegates to plugins when available: tries `codex-companion.mjs` first, then `copilot-companion.mjs`, then falls back to Claude-native. `research-lead` decides scope split and researcher backend routing. `researcher` can use either plugin and falls back to Claude-native research when needed.

Fallback policy:
- `copilot=false` and `codex=true`: route all plugin-backed work to Codex
- `codex=false` and `copilot=true`: route research/execution to Copilot, use Claude-native review fallback
- `codex=false` and `copilot=false`: `fullstack-engineer` uses Claude-native, lead selects Claude model

### Model Config

`.claude/team.md` optionally contains a `## Model Config` section with `### Primary` and `### Secondary` subsections. Each subsection has `role: model-id` lines. When present, `team-lead` resolves the model for each agent by checking Primary first, then Secondary, then Primary `default`, then Secondary `default`, then omitting (no override). `research-lead` propagates model config to `researcher` dispatches.

### Research and Verification Policies

- Code read/search requests should be routed to `research-lead` first, then dispatched to `researcher`.
- `researcher` should output scoped area maps and split oversized areas into smaller sub-areas to reduce context.
- Model focus for research when both plugins are available:
  - `research_kind=code` -> `codex` (stable/accurate investigation)
  - `research_kind=web` -> `copilot` (Claude model path for open-ended synthesis)
  - mixed scope should be split into separate code/web scopes before dispatch
- `verifier` may reuse cached verification only when cache key exactly matches current repo state + command set.

### Plan File Format

Plans are written to `.claude/plan/<slug>.md` with YAML frontmatter containing: `title`, `project` (absolute path), `branch`, `status: draft|approved`, `created`, `size: small|medium|large`, and a `tasks` list. Each task has `id`, `title`, `size`, `parallel_group`, `executor: codex|copilot`, and `status: pending|done`. Tasks in the same `parallel_group` are run in parallel; different groups run sequentially by dependency order.

### Source vs Installed Files

The repo ships two copies of agent prompts:
- `agents/*.md` — canonical source files (edit these)
- `.claude/agents/*.md` — installed copies for this repo (regenerated by `bash scripts/setup.sh --repo`)

Similarly, `SKILL.md` (source) installs to `.claude/skills/teamwork/SKILL.md`, and `commands/*.md` serve as the skill command handlers. The `templates/team.md` is the template copied to a new repo's `.claude/team.md` on first `--repo` install.


### Tamper Protection

Runtime pipeline integrity is enforced through code-level mechanisms:

- **Plan hash**: SHA256 truncated to 16 hex chars, computed at plan creation, verified before each execution step. If hash mismatches, the pipeline halts with `tamper_detected`.
- **Write nonce**: 16-hex random nonce generated at pipeline start, stored in `pipeline-state.json`. All state transitions verify the nonce.
- **Oscillation detection**: Tracks the last 6 stage transitions. If an A→B→A→B pattern is detected (4+ alternations), the pipeline warns the user and offers escape hatches.
- **Repair budget**: Code-enforced single repair cycle via `enforce_repair_budget()`. If budget is exceeded, the pipeline halts with `repair_budget_exhausted`.
- **Review independence**: In adversarial-review mode, reviewer outputs are compared for >95% similarity. If too similar, a re-review from a different perspective is requested.

### Flow Engine

The pipeline supports directed graph-based flow templates in `templates/flow-*.yaml`:

- Node types: `discussion`, `build`, `review`, `execute`, `gate`
- Flow templates: `standard`, `review`, `build-verify`, `pre-release`
- Gate verdicts: 🔴 FAIL, 🟡 ITERATE, 🟢 PASS (mechanical, from evidence)
- Cycle limits: `max_pipeline_steps`, `max_review_loops`, per-edge `max_cycles`
- Escape hatches: `/teamwork:skip`, `/teamwork:pass`, `/teamwork:stop`, `/teamwork:goto`
- Visualization: ASCII pipeline rendering with ✅/▶/○ markers

### State Persistence

Pipeline state is tracked in `.claude/pipeline-state.json` (ephemeral, never committed):

- Fields: `plan_path`, `plan_hash`, `_write_nonce`, `current_stage`, `completed_stages[]`, `pending_stages[]`, `stage_history[]`, `pipeline_steps`, `review_loops`, `repair_count`
- Resume: on pipeline start, existing state is detected and validated (hash chain integrity)
- Graceful termination: `/teamwork:stop` preserves state for later resume
- Cleanup: state file is removed after `git-monitor` successfully commits

## File Conventions

- Agent files: YAML front matter (`name`, `description`, `tools`) then Markdown instructions
- The `tools:` field is a hard constraint — only list tools the agent is actually permitted to use
- `scripts/setup.sh` must keep `set -euo pipefail` and quote all variable expansions
- Conventional Commits format: `type: short imperative summary`
- When modifying agent behavior, update `agents/<name>.md` (source), then re-run `bash scripts/setup.sh --repo` to sync the installed `.claude/agents/` copies

## Versioning Policy

Format: `MAJOR.MINOR.PATCH`

| Segment | Who decides | When to bump |
|---------|-------------|--------------|
| MAJOR | User only | Breaking changes or major milestones decided by user |
| MINOR | Automatic | Any time a new agent is added to `agents/` |
| PATCH | Automatic | Every other change (bug fix, behavior tweak, prompt update, etc.) |

Version is stored in **two places** — both must be updated together:
1. `skills/teamwork/SKILL.md` — `metadata.version` field
2. `.claude-plugin/plugin.json` — `version` field
