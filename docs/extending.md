# Extending the Skill

## Adding a New Agent

### 1. Create the Source File

Create `agents/<name>.md` with YAML front matter followed by Markdown instructions:

```markdown
---
name: <name>
description: <one-line description>
tools: <comma-separated tool list>
---

<Agent instructions>
```

The `tools:` field is a **hard constraint** — only list tools the agent is actually permitted to use. Common tool sets:

| Role Type | Typical Tools |
|-----------|--------------|
| Orchestrator | `Read, Glob, Bash, Agent` |
| Code researcher | `Bash, Read, Glob, Grep` |
| Executor | `Bash, Read, Write, Glob, Grep` |
| Reviewer/Gate | `Bash, Read, Glob, Grep` |
| Planner | `Read, Write, Glob, Grep, Bash, Agent` |

### 2. Register in AGENTS.md

Add a row to the agent inventory table in `AGENTS.md`:

```markdown
| `<name>` | <Role> | <Yes/No/Plan files only> | `agents/<name>.md` | <Purpose> |
```

### 3. Register in SKILL.md (if needed)

If the agent appears in pipeline documentation, add it to the `## Shipped Agents` list in `SKILL.md`.

### 4. Assign to a Model Tier

Edit `templates/model-tiers.md` and add the agent to the `## Agent Assignments` table:

```markdown
| <name> | <tier> | <primary-provider> | <secondary-provider> |
```

Then update `templates/team.md` `## Model Config` sections with a `<name>: <model-id>` entry in both `### Primary` and `### Secondary`.

### 5. Wire into team-lead (if needed)

If the agent participates in the pipeline, add it to `agents/team-lead.md`:
- `## Team` section: agent name and brief role description
- Appropriate step in `## Workflow`

### Project-Specific Agent Overrides

For repo-specific customization without modifying the skill bundle, create `.claude/agents/<name>.md`. Project-level agents take priority over skill bundle agents automatically.

---

## Adding a New Command

### 1. Create the Command File

Create `commands/<name>.md`:

```markdown
---
description: <one-line description>
argument-hint: "<argument hint>"
allowed-tools: Bash, Agent
---

<Command handler instructions>
```

The `allowed-tools:` field restricts what tools the command handler itself can invoke. Command handlers should be orchestrators, not implementors — use `Bash` for plugin checks/config reads and `Agent` for delegation.

### 2. Follow the Delegation Gate Pattern

Command handlers must follow this pattern (from `commands/task.md`):

1. Validate argument
2. Check plugin availability (`CODEX_SCRIPT`, `COPILOT_SCRIPT`)
3. Read `.claude/team.md`
4. Ensure `team-lead` is available (load or error)
5. **Delegation gate**: spawn `team-lead` via `Agent` — this is the only implementation path
6. Report outcome

Do not implement task logic directly in command handlers. Use `Write`, `Edit`, or file-mutating tools only in executor agents.

### 3. Register in commands/ Directory

The command is automatically available as `/teamwork:<filename>` after adding the file (no registration step needed for the plugin system — commands are auto-discovered from the `commands/` directory).

### 4. Document in docs/commands.md

Add a section to `docs/commands.md` following the existing pattern.

---

## Adding a New Executor Backend

The pipeline currently supports three executor backends in `fullstack-engineer`:
1. Codex plugin (`codex-companion.mjs`)
2. Copilot plugin (`copilot-companion.mjs`)
3. Claude-native fallback

To add a new backend:

### 1. Add Detection in fullstack-engineer.md

Edit `agents/fullstack-engineer.md` `## Backend Selection` section to detect the new companion script:

```bash
NEW_SCRIPT=$(find ~/.claude/plugins -name "new-companion.mjs" 2>/dev/null | head -1)
```

### 2. Add Fallback Chain Entry

Add the new backend to the selection priority chain:

```
1. codex-companion.mjs (existing)
2. copilot-companion.mjs (existing)
3. new-companion.mjs (new)
4. Claude-native (always last)
```

### 3. Add Plugin Availability Flag

In `commands/task.md` and `commands/mapping-repo.md`, add detection for the new plugin:

```bash
NEW_OK=false
[ -n "$NEW_SCRIPT" ] && NEW_OK=true || true
echo "codex=$CODEX_OK copilot=$COPILOT_OK new=$NEW_OK"
```

### 4. Update Routing Policy in team-lead.md

Add the new plugin to `## Routing Policy` → execution fallback table:

```
- copilot=true new=true → keep Copilot as default, then apply project fallback rules
- copilot=false new=true → evaluate where new backend sits vs Claude/Codex fallback
- ...
```

### 5. Update Executor Values

If the new backend needs its own `executor:` annotation value in plan tasks, add it to:
- The `## Plan File Format` section in `CLAUDE.md`
- The `plan-lead.md` annotation guidance
- The `team-lead.md` routing policy

Currently only two valid executor values are `codex` and `copilot`. Adding a third value requires updates in all places that parse `executor:` fields.

---

## Adding a Flow Template

### 1. Create the Template File

Create `templates/flow-<name>.yaml`:

```yaml
name: <name>
description: <description>
max_pipeline_steps: 15
max_review_loops: 3
red_behavior: halt
nodes:
  - id: <node-id>
    type: discussion|build|review|execute|gate
    label: "<display label>"
    max_cycles: 3          # only for review/gate nodes
    optional: true         # for optional nodes
edges:
  - from: <node-id>
    to: <node-id>
    condition: "always|green|yellow|design_required|!design_required"
    max_cycles: 1          # per-edge cycle limit
```

### 2. Register in SKILL.md

Add the template to the `## Flow Engine` → `### Available Templates` table in `SKILL.md`.

### 3. Register in team-lead.md

Add the template name to `## Flow Engine` → `### Flow Template Selection` → `Available templates:` list.

### 4. Document in docs/pipeline.md

Add a row to the `## Flow Templates` → `### Available Templates` table.

---

## Versioning Policy

When modifying agents or commands, bump the version in **both** locations:

1. `SKILL.md` — `metadata.version` field (if present in front matter)
2. `.claude-plugin/plugin.json` — `version` field

Version format: `MAJOR.MINOR.PATCH`

| Segment | When to Bump |
|---------|-------------|
| MAJOR | User decision only — breaking changes or major milestones |
| MINOR | Any time a new agent is added to `agents/` |
| PATCH | All other changes (bug fix, behavior tweak, prompt update) |

---

## Post-Edit Checklist

After any modification to source files:

- [ ] `/teamwork:setup --check` (or `bash scripts/setup.sh --check`) — verify plugin and marketplace status
- [ ] `bash test/test-pipeline.sh` — run pipeline-lib.sh unit tests (if pipeline-lib.sh was modified)
- [ ] Update `AGENTS.md` inventory table if a new agent was added
- [ ] Update `docs/agents.md` if agent behavior changed
- [ ] Bump version in `SKILL.md` and `.claude-plugin/plugin.json` (MINOR for new agent, PATCH otherwise)
