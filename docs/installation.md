# Installation

## Plugin Dependencies

Two Claude Code plugins are optional but recommended for best routing flexibility:

### Codex Plugin (by OpenAI)

Enables Codex-backed code review, plan review, research, and execution.

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
```

### Copilot Plugin

Enables Copilot-backed execution and web research.

```
/plugin marketplace add LeePepe/copilot-plugin-cc
/plugin install copilot@copilot-local
```

### After Installing Plugins

Reload and run setup for each installed plugin:

```
/reload-plugins
/codex:setup     # only if codex plugin was installed
/copilot:setup   # only if copilot plugin was installed
```

### Fallback Policy

Plugins are optional. The pipeline always works without any plugin:

| Plugin State | Behavior |
|-------------|----------|
| Copilot available | Prioritize Copilot-backed role execution |
| Copilot unavailable | Use Claude-native role execution |
| Codex available | Tertiary fallback when prior options are unavailable or explicitly disallowed |
| No plugins | Full Claude-native fallback via `fullstack-engineer` |

---

## Install This Skill

### Via Plugin Marketplace (recommended)

```
/plugin marketplace add LeePepe/teamwork
/plugin install teamwork@LeePepe
/reload-plugins
```

Then run setup:

```
/teamwork:setup          # install to current repo (default)
/teamwork:setup --global # install globally to ~/.claude/
```

Equivalent CLI fallback:

```bash
bash scripts/setup.sh --repo
bash scripts/setup.sh --global
```

### Verify Installation

```
/teamwork:setup --check
```

or:

```bash
bash scripts/setup.sh --check
```

---

## Setup Modes

### --repo (default)

Registers marketplaces and creates `.claude/team.md` in the current git repo. Requires running inside a git repository.

```
/teamwork:setup
```

or:

```bash
bash scripts/setup.sh --repo
```

Creates/updates:
- `~/.claude/settings.json` — registers `openai-codex` and `copilot-local` marketplaces
- `.claude/team.md` (from template, if not already present)

The plugin system handles all file distribution (`SKILL.md`, agents, templates) automatically on install.

### --global

Registers marketplaces without creating a `team.md`. Use outside a git repo, or for a one-time global configuration.

```
/teamwork:setup --global
```

or:

```bash
bash scripts/setup.sh --global
```

### --full-agents (legacy)

Preloads all 16 runtime agents to `.claude/agents/` from the plugin bundle.

```
/teamwork:setup --repo --full-agents
/teamwork:setup --global --full-agents
```

or:

```bash
bash scripts/setup.sh --repo --full-agents
bash scripts/setup.sh --global --full-agents
```

Not recommended for normal use. Increases baseline context loaded on every Claude Code session, which can increase 529 overload risk and slow startup. Use only if you need eager agent availability for debugging.

---

## Codex Native Skill Discovery

For use with Codex's native skill system (without the Claude Code plugin system):

```bash
git clone https://github.com/LeePepe/teamwork.git ~/.codex/teamwork
mkdir -p ~/.agents/skills
ln -sfn ~/.codex/teamwork/skills/teamwork ~/.agents/skills/teamwork
ln -sfn ~/.codex/teamwork/skills/teamwork-retro ~/.agents/skills/teamwork-retro
```

Then restart Codex.

---

## Troubleshooting

### Looks Like Teamwork/Subagents Were Not Used

If you see direct `Bash/Write/Edit` implementation in the main session without agent delegation:

1. The task was not started with `/teamwork:task ...` (or an explicit "use teamwork" request) — the skill never activated.
2. `team-lead` could not be loaded. Check with `/teamwork:setup --check` (or `bash scripts/setup.sh --check`). Ensure `team-lead.md` exists in plugin/repo assets.
3. The command was run before setup in that repo. Fix: `/teamwork:setup` (or `bash scripts/setup.sh --repo`)

### 529 overloaded_error on Simple Prompts

Large startup context (too many preloaded agents) can make 529 errors more likely.

1. Re-run setup: `/teamwork:setup` (or `bash scripts/setup.sh --repo`)
2. Verify status: `/teamwork:setup --check` (or `bash scripts/setup.sh --check`)
3. Check for recursive teamwork plugin cache growth:
   ```bash
   find ~/.claude/plugins/cache/teamwork -type d -path "*/teamwork/*/teamwork/*" | head
   ```
   If this prints paths, clean the cache:
   ```bash
   rm -rf ~/.claude/plugins/cache/teamwork
   ```
   Then run `/reload-plugins` in Claude Code.
4. Retry once or twice — the error is often transient.
5. Quick diagnostic:
   ```bash
   claude -p "hi" --disable-slash-commands
   ```
   If this succeeds while normal mode fails, loaded skills/agents context is too heavy.

### Recursive Plugin Cache

`/teamwork:setup` (and `bash scripts/setup.sh`) auto-detects and cleans a recursive teamwork cache (`teamwork/*/teamwork/*` nested paths) when it is safe to do so (i.e., not currently running from within the cache). If running from the cache, manual cleanup is needed:

```bash
rm -rf ~/.claude/plugins/cache/teamwork
```

Then run `/reload-plugins`.

### Missing team-lead Agent

If `/teamwork:task` reports `team_lead=missing`, run `/teamwork:setup` (or `bash scripts/setup.sh --repo`) or manually:

```bash
cp .claude/skills/teamwork/agents/team-lead.md .claude/agents/team-lead.md
```

### Pipeline State Corruption

If the pipeline detects hash mismatch or nonce failure, the state is stale. Delete and restart:

```bash
rm -f .claude/pipeline-state.json
```

Then re-run `/teamwork:task`.
