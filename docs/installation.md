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
| Both available | Follow plan executor annotations (codex/copilot per task) |
| Codex only | All plugin-backed work falls back to Codex |
| Copilot only | Research/execution use Copilot; review gates use Claude-native fallback |
| Neither | Full Claude-native fallback via `fullstack-engineer`; `team-lead` selects model by complexity |

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

### Verify Installation

```
/teamwork:setup --check
```

Or directly:

```bash
bash scripts/setup.sh --check
```

---

## Setup Modes

### --repo (default)

Installs the skill bundle into the current git repo. Requires running inside a git repository.

```bash
bash scripts/setup.sh --repo
# or
/teamwork:setup
```

Creates/updates:
- `.claude/agents/team-lead.md` (bootstrap agent, always preloaded)
- `.claude/skills/teamwork/SKILL.md`
- `.claude/skills/teamwork/agents/` (lazy-load source for all 16 agents)
- `.claude/skills/teamwork/scripts/pipeline-lib.sh`
- `.claude/skills/teamwork/templates/flow-*.yaml`
- `.claude/team.md` (from template, if not already present)

### --global

Installs globally to `~/.claude/`. Use outside a git repo, or to share across all repos.

```bash
bash scripts/setup.sh --global
# or
/teamwork:setup --global
```

Creates/updates:
- `~/.claude/agents/team-lead.md`
- `~/.claude/skills/teamwork/` (full skill bundle)

### --full-agents (legacy)

Preloads all 16 runtime agents to `.claude/agents/` in addition to `team-lead`.

```bash
bash scripts/setup.sh --repo --full-agents
bash scripts/setup.sh --global --full-agents
```

Not recommended for normal use. Increases baseline context loaded on every Claude Code session, which can increase 529 overload risk and slow startup. Use only if you need eager agent availability for debugging.

---

## Manual Install (without the plugin system)

Clone the repo and run setup directly:

```bash
git clone https://github.com/LeePepe/teamwork.git
cd teamwork
bash scripts/setup.sh            # defaults to --repo (project-local)
bash scripts/setup.sh --global   # install globally to ~/.claude/
```

---

## Codex Native Skill Discovery

For use with Codex's native skill system (without the Claude Code plugin system):

```bash
git clone https://github.com/LeePepe/teamwork.git ~/.codex/teamwork
mkdir -p ~/.agents/skills
ln -sfn ~/.codex/teamwork/skills/teamwork ~/.agents/skills/teamwork
```

Then restart Codex.

---

## Troubleshooting

### Looks Like Teamwork/Subagents Were Not Used

If you see direct `Bash/Write/Edit` implementation in the main session without agent delegation:

1. The task was not started with `/teamwork:task ...` (or an explicit "use teamwork" request) — the skill never activated.
2. `team-lead` could not be loaded. Check:
   ```bash
   bash scripts/setup.sh --check
   ```
   Ensure both `.claude/agents/team-lead.md` and `.claude/skills/teamwork/agents/team-lead.md` exist.
3. The command was run before setup in that repo. Fix:
   ```bash
   bash scripts/setup.sh --repo
   ```

### 529 overloaded_error on Simple Prompts

Large startup context (too many preloaded agents) can make 529 errors more likely.

1. Re-run setup to install the latest lighter agent prompts:
   ```bash
   bash scripts/setup.sh --repo
   ```
2. Verify status:
   ```bash
   bash scripts/setup.sh --check
   ```
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

`setup.sh` auto-detects and cleans a recursive teamwork cache (`teamwork/*/teamwork/*` nested paths) when it is safe to do so (i.e., not currently running from within the cache). If running from the cache, manual cleanup is needed:

```bash
rm -rf ~/.claude/plugins/cache/teamwork
```

Then run `/reload-plugins`.

### Missing team-lead Agent

If `/teamwork:task` reports `team_lead=missing`:

```bash
bash scripts/setup.sh --repo
```

Or manually:

```bash
cp agents/team-lead.md .claude/agents/team-lead.md
```

### Agents Directory Missing

If `.claude/agents/` does not exist:

```bash
mkdir -p .claude/agents
bash scripts/setup.sh --repo
```

### Pipeline State Corruption

If the pipeline detects hash mismatch or nonce failure, the state is stale. Delete and restart:

```bash
rm -f .claude/pipeline-state.json
```

Then re-run `/teamwork:task`.
