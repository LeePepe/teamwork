# Command Reference

All commands are slash commands registered under the `teamwork` skill namespace.

---

## /teamwork:task

**File**: `commands/task.md`  
**Argument**: `<task description>` (required)

Runs a full pipeline for a task: plugin check → team config read → team-lead delegation → report.

### Usage

```
/teamwork:task implement JWT auth middleware for the Express API
/teamwork:task refactor the payment module to use the new Stripe SDK
/teamwork:task add dark mode support to the settings page
```

### Steps

1. **Plugin check** — detects `codex-companion.mjs` and `copilot-companion.mjs` in `~/.claude/plugins/`. Does not stop when both are absent; `team-lead` uses Claude-native fallback.
2. **Read team config** — reads `.claude/team.md` for executor routing, review mode, verification commands, and model config.
3. **Ensure team-lead** — copies `team-lead.md` from the skill bundle to `.claude/agents/` if missing. Stops if team-lead cannot be found (run `/teamwork:setup` to fix).
4. **Delegate to team-lead** — spawns `team-lead` with task, routing preferences, plugin availability, verification preferences, design-first policy, and model config.
5. **Report** — returns research summary, plan path, design stage result, modified files, failed/skipped tasks, verifier result, final review result, boundary violations, suggested follow-up actions, model config applied.

If the argument is empty, the command stops and asks for a task description.

---

## /teamwork:setup

**File**: `commands/setup.md`  
**Argument**: `[--global|--repo|--check|--full-agents]` (optional, default `--repo`)

Installs the teamwork skill bundle into the repo or global `~/.claude/`. Delegates entirely to `scripts/setup.sh`.

### Usage

```
/teamwork:setup                    # install to current repo (default)
/teamwork:setup --global           # install globally to ~/.claude/
/teamwork:setup --check            # check status only, no install
/teamwork:setup --full-agents      # repo install + preload all runtime agents (legacy mode)
/teamwork:setup --repo --full-agents
/teamwork:setup --global --full-agents
```

### What --repo Does

- Installs `team-lead.md` to `.claude/agents/` (bootstrap agent, always preloaded)
- Prunes preloaded runtime agents from `.claude/agents/` if they match the bundled copies (keeps custom overrides)
- Copies all agents to `.claude/skills/teamwork/agents/` (lazy-load source)
- Copies `SKILL.md` to `.claude/skills/teamwork/SKILL.md`
- Copies `pipeline-lib.sh` to `.claude/skills/teamwork/scripts/`
- Copies flow templates to `.claude/skills/teamwork/templates/`
- Creates `.claude/team.md` from `templates/team.md` if it does not exist
- Registers `openai-codex` and `copilot-local` plugin marketplaces in `~/.claude/settings.json`
- Detects and cleans recursive teamwork plugin cache if safe to do so

### What --check Does

Reports:
- Which plugins are installed (`codex`, `copilot`)
- Whether bootstrap agents are preloaded (warns if so — higher baseline context)
- Whether the skill bundle is complete (all agent files present in `~/.claude/skills/teamwork/agents/`)
- Whether runtime agents are preloaded (warns if so)
- Whether `SKILL.md` is installed
- Test harness availability
- `pipeline-lib.sh` presence

Exits 0 on success, 1 if any required files are missing.

### What --full-agents Does

Preloads all 16 runtime agents to `.claude/agents/` in addition to `team-lead`. Use for legacy eager-load behavior. Not recommended for normal use — increases baseline context and 529 overload risk.

---

## /teamwork:mapping-repo

**File**: `commands/mapping-repo.md`  
**Argument**: `[--update]` (optional)

Maps and documents the repository architecture using the full pipeline. Produces `ARCHITECTURE.md`, `docs/` topic files, and a simplified `AGENTS.md`.

### Usage

```
/teamwork:mapping-repo             # full mapping (creates all docs)
/teamwork:mapping-repo --update    # refresh existing docs
```

### Steps

1. **Plugin check** — same as `/teamwork:task`
2. **Read team config** — reads `.claude/team.md`
3. **Ensure team-lead** — same as `/teamwork:task`
4. **Delegate to team-lead** — spawns `team-lead` with the mapping task specification:
   - Full mapping: produce `ARCHITECTURE.md`, all `docs/` topic files, and simplified `AGENTS.md`
   - Update mode: refresh docs based on current repo state, preserve existing structure where valid
5. **Report** — files produced, research summary, plan path, modified files, verification result, final review result

---

## /teamwork:flow

**File**: `commands/flow.md`  
**Argument**: `[template-name]` (optional)

Selects a flow template or displays the current flow state.

### Usage

```
/teamwork:flow                     # show current flow state and position
/teamwork:flow standard            # select standard template
/teamwork:flow pre-release         # select pre-release template
/teamwork:flow review              # select review-only template
/teamwork:flow build-verify        # select quick build-verify template
```

### Available Templates

| Template | Description |
|----------|-------------|
| `standard` | Full research → plan → review → execute → verify → final-review (default) |
| `review` | Review-only flow for existing code or PRs |
| `build-verify` | Quick build-and-verify for confident changes |
| `pre-release` | Extended pipeline with security and performance review gates |

Note: Template can only be changed before execution begins. Changing templates mid-pipeline warns about implications.

---

## /teamwork:skip

**File**: `commands/skip.md`

Skips the current pipeline node without completing it and advances to the next stage.

### Usage

```
/teamwork:skip
```

### Behavior

1. Marks the current node as `skipped` in pipeline state
2. Advances to the next node in the flow graph
3. Logs the skip action in `stage_history`
4. Reports the new current position with ASCII flow visualization

Use when the current stage is blocked or unnecessary. Skipped stages can be revisited with `/teamwork:goto`.

---

## /teamwork:pass

**File**: `commands/pass.md`

Forces the current gate node to a 🟢 PASS verdict regardless of automated evidence.

### Usage

```
/teamwork:pass
```

### Behavior

1. Sets the current gate node's verdict to `🟢 PASS`
2. Advances to the next node in the flow graph
3. Logs the forced pass in `stage_history` with `forced: true`
4. Reports the new current position with flow visualization

Use when manual verification confirms the gate should pass despite automated evidence. Forced passes are logged and visible in the pipeline summary. Only applicable to `gate` and `review` node types.

---

## /teamwork:stop

**File**: `commands/stop.md`

Gracefully halts the pipeline and preserves current state for later resume.

### Usage

```
/teamwork:stop
```

### Behavior

1. Saves current pipeline state to `.claude/pipeline-state.json` via `save_pipeline_state()`
2. Marks current stage as `paused`
3. Reports saved state location and resume instructions
4. Exits without cleanup

Resume by running `/teamwork:task` again — the pipeline detects saved state and offers to continue from the current stage.

---

## /teamwork:goto

**File**: `commands/goto.md`  
**Argument**: `<node-id>` (required)

Jumps to a specific node in the current flow graph.

### Usage

```
/teamwork:goto verify              # jump directly to verification
/teamwork:goto execute             # jump to execution stage
/teamwork:goto plan-review         # jump back to plan review
```

### Behavior

1. Validates the target node exists in the current flow template
2. Marks all intermediate nodes as `skipped`
3. Sets the target node as current in pipeline state
4. Logs the jump in `stage_history` with `jumped_from` and `jumped_to`
5. Warns about any skipped gate/review nodes
6. Reports the new current position with flow visualization

Jumping backward is allowed but resets completed status of intermediate nodes. Use with caution — skipping stages may produce incomplete results.
