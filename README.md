# Planning Team Skill for Claude Code

A Claude Code skill that orchestrates a full **plan → review → execute** pipeline using a team of agents.

Claude plans, Codex reviews, and tasks are automatically routed to **Codex** (strict/formal work) or **Copilot** (everything else).

## How It Works

```
/planning-team <your feature or fix>
        │
        ▼
   team-lead (Claude)
        ├── planner      → creates .claude/plan/<slug>.md
        │                   each task annotated: executor: codex | copilot
        ├── plan-reviewer (Codex)
        │                → reviews or adversarially challenges the plan
        └── executors (parallel where possible)
              codex-coder  ← TypeScript, APIs, tests, business logic
              copilot      ← Swift, Kotlin, UI, scripts, platform code
```

## Dependencies

Install both plugins in Claude Code first:

**Codex plugin** (by OpenAI):
```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
```

**Copilot plugin** (this org):
```
/plugin marketplace add LeePepe/copilot-plugin-cc
/plugin install copilot@copilot-local
```

Then reload:
```
/reload-plugins
/codex:setup
/copilot:setup
```

## Install This Skill

### Install agent definitions

```bash
cp agents/*.md ~/.claude/agents/
```

### Install the skill

```bash
# Global
cp SKILL.md ~/.claude/skills/planning-team/SKILL.md

# Or project-level
cp SKILL.md .claude/skills/planning-team/SKILL.md
```

## Usage

```
/planning-team implement a JWT auth middleware for the Express API
```

```
/planning-team refactor the payment module to use the new Stripe SDK
```

## Per-Repo Customization

### Routing preferences

Copy `templates/team.md` to `.claude/team.md` in your repo:

```bash
cp templates/team.md /path/to/your/repo/.claude/team.md
```

Then edit to set routing rules and review mode:

```markdown
## Executor Routing
- *.swift → copilot
- *.ts    → codex

## Review Mode
default: adversarial-review
```

### Project-specific executors

Add repo-aware agent definitions to `.claude/agents/` in your repo:

- `.claude/agents/codex-coder.md` — knows your TS conventions, test setup, etc.
- `.claude/agents/copilot.md` — knows your xcodebuild commands, Sapphire structure, etc.

Project-level agents automatically override global ones.

## Executor Routing Defaults

| Executor | Handles |
|----------|---------|
| `codex` | TypeScript/JS · APIs · types · tests · DB migrations · algorithms |
| `copilot` | Swift/SwiftUI · Kotlin/Android · UI · scripts · exploratory refactoring |

## Related

- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — OpenAI's Codex plugin
- [copilot-plugin-cc](https://github.com/LeePepe/copilot-plugin-cc) — Copilot CLI plugin
