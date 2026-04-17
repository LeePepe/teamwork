# Configuration

Per-repo configuration lives in `.claude/team.md`. This file is read by `team-lead` and `planner-lead` at the start of every pipeline run. A template is provided at `templates/team.md` and is copied automatically on the first setup (`/teamwork:setup` or `bash scripts/setup.sh --repo`).

## team.md Format

```markdown
# Team Config

## Executor Routing
(routing rules or empty for defaults)

## Review Mode
default: review

## Verification
(verification commands or empty)

## Model Config

### Primary
default: claude-sonnet-4.6
team-lead: claude-opus-4.6
...

### Secondary
default: gpt-5.4
...

## Definition of Done
(answers to three DoD questions or empty for auto-inference)

## Flow Template
(template name or empty for default standard)

## Specialty Reviewers
(list of specialty reviewer roles or empty)

## Notes
(context for planner-lead and team-lead about this repo)
```

---

## Executor Routing

Controls which executor (`codex` or `copilot`) handles tasks. Only two valid executor values.

| Executor | Task Types |
|----------|------------|
| `codex` | Rigorous or heavy tasks: complex algorithms, security-sensitive code, auth/authz, data migrations, strict correctness requirements, large-scale refactors, critical business logic |
| `copilot` | All other tasks: UI changes, simple features, scripts, config, exploratory code, docs, straightforward bug fixes |

Routing is determined by **task weight and rigor**, not file type. The default is for `planner-lead` to annotate each task with the appropriate executor based on task characteristics.

### Per-Repo Overrides

Specify file-glob-based routing in `## Executor Routing`:

```markdown
## Executor Routing
- *.swift, *.m, *.xib → copilot
- *.ts, *.tsx, *.js   → codex
- src/ui/**           → copilot
- src/api/**          → codex
- tests/**            → codex
- *.py, *.sh          → copilot
```

When overrides are specified, `planner-lead` uses them when annotating tasks. Overrides take precedence over the default task-weight routing.

### Plugin Availability Overrides

At runtime, `team-lead` adjusts routing based on actual plugin availability:

| Availability | Behavior |
|-------------|----------|
| `copilot=true` | Prioritize Copilot-backed role execution |
| `copilot=false` | Use Claude-native role execution |
| Codex available | Tertiary fallback when prior options are unavailable or explicitly disallowed |

---

## Review Mode

Controls whether plan review is standard or adversarial.

```markdown
## Review Mode
default: review
```

| Mode | Description |
|------|-------------|
| `review` | Standard quality review — checks correctness, completeness, risks |
| `adversarial-review` | Adversarial challenge — questions assumptions, finds blind spots, proposes simpler alternatives |

**Default selection** (when not overridden):
- `adversarial-review` for large or architectural plans
- `review` for all other plans

Override per-repo by setting `default: adversarial-review` in `.claude/team.md`.

---

## Verification

Post-execution commands that `verifier` runs. Commands execute in repo root.

```markdown
## Verification
- npm run lint
- npm test
- pnpm -r test
- go test ./...
- make test
```

Command resolution order in `verifier`:
1. Commands from `.claude/team.md ## Verification`
2. Task-level verification commands from the plan file
3. If none found: return `needs_manual_verification`

### Cache Behavior

`verifier` builds a cache key from the combination of:
- Current repo state (git commit SHA or working tree hash)
- Verification command set

An exact cache hit (same repo state + same commands) may be reused without re-running. A cache miss runs all commands and stores the result.

---

## Model Config

Controls which model is used for each agent. Uses a two-tier Primary/Secondary resolution.

```markdown
## Model Config

### Primary
default: claude-sonnet-4.6
team-lead: claude-opus-4.6
planner-lead: claude-opus-4.6
linter: gpt-5.4
researcher: gpt-5.4
plan-reviewer: gpt-5.4
designer: claude-sonnet-4.6
fullstack-engineer: claude-sonnet-4.6
verifier: gpt-5.4-mini
final-reviewer: gpt-5.4
git-monitor: gpt-5.4-mini
pm: gpt-5.4
security-reviewer: gpt-5.4
devil-advocate: claude-haiku-4.5
a11y-reviewer: gpt-5.4
perf-reviewer: gpt-5.4
user-perspective: claude-sonnet-4.6

### Secondary
default: gpt-5.4
team-lead: gpt-5.4
planner-lead: gpt-5.4
linter: claude-sonnet-4.6
...
```

### Resolution Order

When `team-lead` spawns any agent via `task()`:

1. Look up the agent's role name in **Primary** map
2. If not found in Primary, look up in **Secondary** map
3. If not found in either, check **Primary** `default` key
4. If still not found, check **Secondary** `default` key
5. If none exists, omit `model` parameter (no override)

### Model Tiers

Agent model assignments are organized into four autonomy tiers defined in `templates/model-tiers.md`:

| Tier | Autonomy Level | Claude Model | OpenAI Model |
|------|----------------|--------------|--------------|
| 1 | Full autonomy | `claude-opus-4.6` | `gpt-5.4` |
| 2–3 | Scoped autonomy / task execution | `claude-sonnet-4.6` | `gpt-5.3-codex` |
| 4 | Mechanical | `claude-haiku-4.5` | `gpt-5.4-mini` |

Tier 1 agents (orchestrators/planners): `team-lead`, `planner-lead`, `plan-reviewer`, `final-reviewer`  
Tier 2 agents (scoped workers): `fullstack-engineer`, `designer`, `researcher`, `pm`, `security-reviewer`, `a11y-reviewer`, `perf-reviewer`, `user-perspective`  
Tier 4 agents (mechanical): `devil-advocate`, `verifier`, `git-monitor`

---

## Definition of Done

Answers to three pre-flight questions that establish acceptance criteria before planning. Leave blank to auto-infer from codebase context.

```markdown
## Definition of Done

<!-- What does "done" look like? -->
All API endpoints return correct responses and are covered by integration tests.

<!-- How will we verify it? -->
npm test && npm run lint

<!-- How will we evaluate quality? -->
No TypeScript errors, test coverage >= 80%, no OWASP Top 10 vulnerabilities.
```

Auto-inference sources (in order):
- `package.json` → infers `npm test`, `npm run lint`
- `Makefile` → infers `make test`
- `.github/workflows/` → infers CI validation
- `CLAUDE.md` → extracts verification commands from `## Commands`
- Existing test directories → runs test suites

If auto-inference produces nothing, `planner-lead` prompts the three DoD questions interactively.

Lint policy (mandatory):
- verifier must include lint command evidence before delivery gate can pass
- recommended layered architecture model: `Types -> Config -> Repo -> Service -> Runtime -> UI`
- lower layers must not reverse-depend on upper layers
- lint diagnostics should include: violated rule, why it exists, and concrete fix guidance

---

## Flow Template

Overrides the default flow template selection.

```markdown
## Flow Template
default: pre-release
```

Options: `standard` (default), `review`, `build-verify`, `pre-release`

See `docs/pipeline.md` for full template descriptions.

---

## Specialty Reviewers

Lists specialty reviewer roles to include in review stages. Activated during pre-release flow or adversarial-review mode.

```markdown
## Specialty Reviewers
- security-reviewer
- perf-reviewer
- a11y-reviewer
- devil-advocate
- pm
- user-perspective
```

When listed, these agents are invoked by `team-lead` at the appropriate pipeline stage.

---

## Notes

Free-form context for `planner-lead` and `team-lead` about this repo.

```markdown
## Notes
This is a React + TypeScript monorepo using pnpm workspaces.
Main app is in packages/app/, shared utils in packages/common/.
All new features require a Storybook story.
```

`git-monitor` also reads this section for PR format hints.

---

## Project-Specific Agent Overrides

Place agent files in `.claude/agents/` to override the global skill bundle. Project-level agents take priority automatically.

Overrideable agents:
- `.claude/agents/researcher.md`
- `.claude/agents/planner-lead.md`
- `.claude/agents/designer.md`
- `.claude/agents/fullstack-engineer.md`
- `.claude/agents/verifier.md`
- `.claude/agents/final-reviewer.md`

Use overrides to add repo-specific conventions (test setup, linting rules, stack knowledge) to agent prompts without modifying the skill bundle.
