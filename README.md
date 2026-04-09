# Teamwork Skill for Claude Code

A Claude Code skill that orchestrates a full **research → plan → review → execute → verify → final-review** pipeline using a team of agents.

Copilot/Codex/Claude can all participate via fallback routing: if Copilot is unavailable use Codex; if both Codex and Copilot are unavailable, use Claude-native execution with model selection by team-lead.

## How It Works

```
/teamwork:task <your feature or fix>
        │
        ▼
   team-lead (orchestrates only — never modifies files directly)
        ├── researcher(s) → lead decides split; runs in parallel when scopes are independent
        │                   backend: copilot|codex|claude, then merged for planner
        ├── planner      → creates .claude/plan/<slug>.md
        │                   each task annotated: executor: codex | copilot
        ├── plan-reviewer
        │                → reviews or adversarially challenges the plan (Codex or Claude fallback)
        ├── executors (parallel where possible)
        │     codex-coder  ← rigorous/heavy tasks (algorithms, security, migrations, critical logic)
        │     copilot      ← all other tasks (UI, scripts, config, simple features)
        │     claude-coder ← fallback when codex/copilot are both unavailable
        ├── verifier       → runs verification commands before completion
        ├── final-reviewer → runs final review (Codex when available, Claude fallback otherwise)
        └── git-monitor    → (optional) commit, PR creation, CI/comment monitoring
```

## Dependencies

Plugins in Claude Code are optional but recommended:

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
```

Run setup only for the plugins you installed:
```
/codex:setup     # only if codex plugin was installed
/copilot:setup   # only if copilot plugin was installed
```

Fallback policy:
- Copilot unavailable + Codex available: all plugin-backed work falls back to Codex
- Codex unavailable + Copilot available: research/execution use Copilot, review gates use Claude fallback when needed
- Codex unavailable + Copilot unavailable: full Claude-native fallback; `team-lead` chooses model (`haiku|sonnet|opus`)
- Multiple research scopes: `team-lead` decides split and runs `researcher` workers in parallel

## Install This Skill

```
/plugin marketplace add LeePepe/teamwork
/plugin install teamwork@LeePepe
/reload-plugins
```

Then run setup (`--repo` by default, or pass `--global` for global install):

```
/teamwork:setup
/teamwork:setup --global
```

Check status at any time:

```
/teamwork:setup --check
```

### Manual install (without the plugin system)

```bash
git clone https://github.com/LeePepe/teamwork.git
cd teamwork
bash scripts/setup.sh            # defaults to --repo (project-local)
bash scripts/setup.sh --global   # install globally to ~/.claude
```

## Usage

```
/teamwork:task implement a JWT auth middleware for the Express API
```

```
/teamwork:task refactor the payment module to use the new Stripe SDK
```

## Troubleshooting

### `529 overloaded_error` on simple prompts (for example `hi`)

This is usually an upstream model capacity error, but large startup context can make it more likely.

If this appears right after installing this skill:

1. Re-run setup so the latest (lighter) agent prompts are installed:
   ```bash
   bash scripts/setup.sh --repo
   ```
2. Verify status:
   ```bash
   bash scripts/setup.sh --check
   ```
3. Retry once or twice (the error is often transient).
4. As a quick diagnostic, run:
   ```bash
   claude -p "hi" --disable-slash-commands
   ```
   If this succeeds consistently while normal mode fails, your loaded skills/agents context is likely too heavy.

## Per-Repo Customization

### Routing preferences

Run `bash scripts/setup.sh --repo` inside your repo — it copies a `team.md` template to `.claude/team.md` automatically. Then edit it to set routing rules, review mode, and verification commands:

```markdown
## Executor Routing
- *.swift → copilot
- *.ts    → codex

## Review Mode
default: adversarial-review

## Verification
- npm run lint
- npm test
```

### Project-specific agents

Add repo-aware agent definitions to `.claude/agents/` in your repo:

- `.claude/agents/codex-coder.md` — knows your TS conventions, test setup, etc.
- `.claude/agents/copilot.md` — knows your xcodebuild commands, project structure, etc.
- `.claude/agents/researcher.md` — gathers repo/external context and writes planning briefs
- `.claude/agents/claude-coder.md` — Claude-native coding fallback when plugins are unavailable
- `.claude/agents/verifier.md` — enforces repo-specific verification strategy and output style
- `.claude/agents/final-reviewer.md` — runs final review policy (Codex when available, Claude fallback otherwise)

Project-level agents automatically override global ones.

## Executor Routing Defaults

| Executor | When to use |
|----------|-------------|
| `codex` | Rigorous or heavy tasks: complex algorithms, security-sensitive code, auth/authz, data migrations, strict correctness requirements, large-scale refactors, critical business logic |
| `copilot` | All other tasks: UI changes, simple features, scripts, config, exploratory code, docs, straightforward bug fixes |

## Related

- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — OpenAI's Codex plugin
- [copilot-plugin-cc](https://github.com/LeePepe/copilot-plugin-cc) — Copilot CLI plugin
