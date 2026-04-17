# Teamwork Skill for Claude Code and Codex

A Claude Code skill that orchestrates a full **plan-led planning → dual plan gate → execute → verify → PM delivery gate → final-review coalition** pipeline.

The `fullstack-engineer` executor uses backend priority: Copilot → Claude-native → Codex (tertiary fallback).

## How It Works

```
/teamwork:task <your feature or fix>
        │
        ▼
   team-lead (orchestrates only — never modifies files directly)
        ├── planner-lead → orchestrates researcher + designer + linter and writes plan directly
        │    ├── researcher(s) → scoped parallel research workers
        │    └── designer      → design output when required
        │    └── linter        → layered dependency lint contract + CI gate
        ├── plan-reviewer + pm (joint plan gate, both must pass)
        ├── fullstack-engineer (parallel where possible)
        │     auto-selects: Copilot → Claude-native → Codex
        ├── verifier       → runs verification commands
        ├── pm             → supervises task outcomes and test evidence
        ├── final-reviewer → runs code review + leads specialty review coalition
        │    ├── security-reviewer
        │    ├── devil-advocate
        │    ├── a11y-reviewer
        │    ├── perf-reviewer
        │    └── user-perspective
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
- Copilot available: prioritize Copilot-backed role execution
- Copilot unavailable: use Claude-native role execution
- Codex is tertiary fallback (used when prior options are unavailable or explicitly disallowed)
- Plan phase ownership: `planner-lead` owns research consolidation, design handoff, and plan generation

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

Equivalent CLI fallback (including Codex sessions without slash commands):

```bash
bash scripts/setup.sh --repo
bash scripts/setup.sh --global
```

### Codex support

This repository now includes Codex plugin metadata and skill entrypoints:
- `.codex-plugin/plugin.json`
- `skills/teamwork/SKILL.md`
- `skills/teamwork-retro/SKILL.md`

Install for Codex via native skill discovery:

```bash
git clone https://github.com/LeePepe/teamwork.git ~/.codex/teamwork
mkdir -p ~/.agents/skills
ln -sfn ~/.codex/teamwork/skills/teamwork ~/.agents/skills/teamwork
ln -sfn ~/.codex/teamwork/skills/teamwork-retro ~/.agents/skills/teamwork-retro
```

Then restart Codex.

Setup now uses a lightweight default:
- Does not preload runtime agents by default
- Loads agents progressively by stage from the skill bundle/plugin assets:
  - planning stage: `planner-lead` (dispatches `researcher`, `designer`, `linter` when needed)
  - plan gate stage: `plan-reviewer` + `pm`
  - execution stage: `fullstack-engineer`, `verifier`, `pm`, `final-reviewer`, optional `git-monitor`

Planning policy:
- `planner-lead` consolidates scoped research and directly produces plan
- `designer` is dispatched by `planner-lead` when design output is required
- plan gate is dual-key: `plan-reviewer` (technical) + `pm` (product)

Delivery policy:
- `pm` supervises whether task results and test evidence satisfy user-facing acceptance criteria
- `verifier` remains the source of command-level test evidence
- `final-reviewer` performs code review and aggregates specialty reviewer findings
- lint is mandatory in verifier and CI: layered dependency violations block merge
- canonical dependency layers: `Types -> Config -> Repo -> Service -> Runtime -> UI`
- lower layers cannot reverse-depend on upper layers
- lint errors must explain: why rule exists + correct fix direction (for agent self-repair)

Verification policy:
- verifier uses cache keyed by repo state + verification command set
- exact cache hit may be reused; cache miss runs commands and writes result back

If you prefer legacy behavior (preload all runtime agents), use:

```
/teamwork:setup --full-agents
```

or:

```bash
bash scripts/setup.sh --repo --full-agents
```

Check status at any time:

```
/teamwork:setup --check
```

or:

```bash
bash scripts/setup.sh --check
```

## Usage

```
/teamwork:task implement a JWT auth middleware for the Express API
```

```
/teamwork:task refactor the payment module to use the new Stripe SDK
```

```
/teamwork:mapping-repo           # Map and document repo architecture (produces ARCHITECTURE.md + docs/)
/teamwork:mapping-repo --update  # Refresh existing architecture docs
```

Run `/teamwork:mapping-repo` to map and document this repository's architecture. The command produces `ARCHITECTURE.md` at repo root, topic files in `docs/`, and a simplified `AGENTS.md` index — following the harness engineering approach of treating documentation as a machine-readable contract.

## Troubleshooting

### Looks like teamwork/subagents were not used

If you see direct `Bash/Write/Edit` implementation in the main session, usually one of these happened:

1. The task was not started with `/teamwork:task ...` (or an explicit "use teamwork" request), so the teamwork skill never activated.
2. `team-lead` could not be loaded; run `/teamwork:setup --check` (or `bash scripts/setup.sh --check`) and ensure `team-lead.md` exists in plugin/repo assets.
3. The command was run before setup in that repo; run `/teamwork:setup` (or `bash scripts/setup.sh --repo`).

### `529 overloaded_error` on simple prompts (for example `hi`)

This is usually an upstream model capacity error, but large startup context can make it more likely.

If this appears right after installing this skill:

1. Re-run setup: `/teamwork:setup` (or `bash scripts/setup.sh --repo`)
2. Verify status: `/teamwork:setup --check` (or `bash scripts/setup.sh --check`)
3. Check for recursive teamwork plugin cache growth:
   ```bash
   find ~/.claude/plugins/cache/teamwork -type d -path "*/teamwork/*/teamwork/*" | head
   ```
   If this prints paths, clean cache:
   ```bash
   rm -rf ~/.claude/plugins/cache/teamwork
   ```
   Then run `/reload-plugins` in Claude Code.
4. Retry once or twice (the error is often transient).
5. As a quick diagnostic, run:
   ```bash
   claude -p "hi" --disable-slash-commands
   ```
   If this succeeds consistently while normal mode fails, your loaded skills/agents context is likely too heavy.

## Per-Repo Customization

### Routing preferences

Run `/teamwork:setup` inside your repo (or `bash scripts/setup.sh --repo`) — it creates `.claude/team.md` from the template automatically. Then edit it to set routing rules, review mode, and verification commands:

```markdown
## Routing
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

- `.claude/agents/fullstack-engineer.md` — unified executor, knows your project conventions and test setup
- `.claude/agents/planner-lead.md` — unified planning owner (research + design + plan)
- `.claude/agents/researcher.md` — gathers repo/external context and writes planning briefs
- `.claude/agents/designer.md` — produces design plan artifacts for design-heavy requests
- `.claude/agents/pm.md` — co-approves plan and supervises task/test delivery
- `.claude/agents/verifier.md` — enforces repo-specific verification strategy and output style
- `.claude/agents/final-reviewer.md` — leads coalition review + final code review

Project-level agents automatically override global ones.

## Executor Routing

Routing is determined by task weight/rigor, not file type:

| Executor | Task Types |
|----------|------------|
| `codex` | Rigorous or heavy tasks: complex algorithms, security-sensitive code, auth/authz, data migrations, strict correctness, large-scale refactors, critical business logic |
| `copilot` | All other tasks: UI changes, simple features, scripts, config, exploratory code, docs, straightforward bug fixes |

## Related

- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — OpenAI's Codex plugin
- [copilot-plugin-cc](https://github.com/LeePepe/copilot-plugin-cc) — Copilot CLI plugin
