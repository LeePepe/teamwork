---
name: planning-team
description: Orchestrate a full planning + review + execution pipeline using a team of agents. Claude plans, Codex reviews, and tasks are routed to Codex or Copilot based on type. Depends on codex-plugin-cc and copilot-plugin-cc.
---

# Planning Team Skill

Orchestrate a structured multi-agent pipeline: Claude plans, Codex reviews the plan, and tasks are automatically routed to the right executor (Codex for strict/formal work, Copilot for everything else).

## Dependencies

Both plugins must be installed in Claude Code before using this skill:

- **[codex-plugin-cc](https://github.com/openai/codex-plugin-cc)** — Codex CLI integration (`/codex:rescue`, `/codex:review`)
- **[copilot-plugin-cc](https://github.com/LeePepe/copilot-plugin-cc)** — Local Copilot CLI integration (`/copilot:rescue`, `/copilot:review`)

Install with:
```bash
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex

/plugin marketplace add LeePepe/copilot-plugin-cc
/plugin install copilot@copilot-local

/reload-plugins
```

## When to Use

- You have a non-trivial feature or refactor that spans multiple files
- You want a plan reviewed before any code is written
- You want parallel execution across Codex and Copilot
- You want per-repo control over which executor handles which file types

## Trigger

```
/planning-team <description of what to build or fix>
```

Or natural language:
```
Use the planning team to implement <feature>
```

## What It Does

```
team-lead
  ├── planner        → .claude/plan/<slug>.md  (with executor annotations)
  ├── plan-reviewer  → Codex reviews the plan (regular or adversarial)
  └── executors (parallel where possible):
        executor: codex   → codex-coder  (via /codex:rescue)
        executor: copilot → copilot      (via /copilot:rescue)
```

## Workflow

### Step 1 — Check dependencies

```bash
# Verify codex plugin
node $(find ~/.claude/plugins -name "codex-companion.mjs" | head -1) setup --json

# Verify copilot plugin
node $(find ~/.claude/plugins -name "copilot-companion.mjs" | head -1) setup --json
```

If either plugin is missing or unavailable, stop and tell the user what to install.

### Step 2 — Read repo config

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
cat "$REPO_ROOT/.claude/team.md" 2>/dev/null
```

If `.claude/team.md` exists, extract:
- Executor routing overrides (which file types go to codex vs copilot)
- Preferred review mode (`review` or `adversarial-review`)

### Step 3 — Invoke team-lead agent

Delegate to the `team-lead` agent with the user's request and any routing preferences from `.claude/team.md`:

```
Agent: team-lead
Prompt: <user's description>
        Routing preferences: <from .claude/team.md, or "use defaults">
```

The team-lead handles the full pipeline:
1. Calls `planner` → creates the plan with `executor: codex|copilot` per task
2. Calls `plan-reviewer` → Codex reviews (mode decided by team-lead based on plan size)
3. Routes approved tasks to `codex-coder` or `copilot` executor agents

### Step 4 — Report

Present the team-lead's summary:
- Plan file location
- Files changed per executor
- Any failed or skipped tasks
- Recommended follow-up steps

## Per-Repo Customization

Drop a `.claude/team.md` in your repo to override defaults:

```markdown
## Executor Routing
- *.swift, *.m → copilot
- *.ts, *.tsx  → codex
- tests/**     → codex

## Review Mode
default: adversarial-review
```

Or add project-specific executor agents to `.claude/agents/`:
- `.claude/agents/codex-coder.md` — repo-aware Codex executor (knows your TS conventions)
- `.claude/agents/copilot.md` — repo-aware Copilot executor (knows your xcodebuild commands)

Project-level agents automatically take priority over global ones.

## Executor Routing Defaults

| Executor | Task Types |
|----------|-----------|
| `codex` | TypeScript/JS, APIs, types, tests, DB migrations, algorithms, business logic |
| `copilot` | Swift/SwiftUI, Kotlin/Android, UI, exploratory refactoring, platform code, scripts |

## Agent Definitions

This skill ships with the following agent definitions (install to `~/.claude/agents/`):

- `team-lead.md` — orchestrator
- `planner.md` — plan creator with executor annotations
- `plan-reviewer.md` — Codex-powered plan reviewer
- `codex-coder.md` — Codex executor
- `copilot.md` — Copilot executor

See the `agents/` directory for definitions. Copy to `~/.claude/agents/` or use the install script.

## Install Agents

```bash
# Copy agent definitions to global agents directory
cp agents/*.md ~/.claude/agents/
```

Or symlink for live updates:
```bash
for f in agents/*.md; do
  ln -sf "$(pwd)/$f" ~/.claude/agents/$(basename $f)
done
```
