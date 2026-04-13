---
name: teamwork
description: Multi-agent pipeline for complex tasks — research, plan, review, design (when needed), execute, verify, and ship. Supports Codex/Copilot/Claude fallback routing.
allowed-tools: Bash, Agent
---

# Teamwork Skill

Run a structured multi-agent pipeline: team-lead delegates research orchestration to research-lead, researcher workers gather scoped context, planner writes a plan, plan-reviewer gates quality, designer produces design plans for design-heavy tasks, executors implement approved tasks, verifier confirms checks, and final-reviewer performs final code review.

## Dependencies

Plugins are optional but recommended:

- **[codex-plugin-cc](https://github.com/openai/codex-plugin-cc)** for Codex task/review integration
- **[copilot-plugin-cc](https://github.com/LeePepe/copilot-plugin-cc)** for local Copilot task integration

Use these commands:

```bash
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex

/plugin marketplace add LeePepe/copilot-plugin-cc
/plugin install copilot@copilot-local

/reload-plugins
```

## Triggers

```text
/teamwork:task <description>
/teamwork:mapping-repo           # map and document repo architecture
/teamwork:mapping-repo --update  # refresh existing docs
```

Natural language trigger:

```text
Use teamwork to implement <feature>
```

Activation safety:
- Only activate this skill for explicit teamwork intent (`/teamwork:task ...` or clear request to "use teamwork").
- Do not activate for casual chat, greetings, or unrelated prompts.
- If the user does not explicitly trigger teamwork, normal Claude execution may run directly without `team-lead`/subagents.

**Default on activation: immediately spawn `team-lead`.** This skill's only role is plugin validation, team config read, and Agent delegation — never direct implementation. Using `Write`, `Edit`, or any file-mutating tool in this skill entry is a hard pipeline violation.

> To install or check status, use `/teamwork:setup` (available after installing this plugin).

## Pipeline

```text
team-lead
  ├── progressive load guides
  │     guide A: research stage  → load research-lead only
  │     guide B: plan stage      → load planner + plan-reviewer only
  │     guide C: design stage    → load designer only when design work is required
  │     guide D: execution stage → load executors/gates only when needed
  ├── research-lead  → split scopes, route backends, dispatch/merge researcher workers
  │     └── researcher(s)  → parallel by independent scope
  │                          default focus: code investigation -> codex, web research -> copilot (Claude path)
  │                          outputs are merged by research-lead for planner
  ├── planner        → writes .claude/plan/<slug>.md with executor annotations
  ├── plan-reviewer  → reviews plan (review or adversarial-review)
  ├── designer       → creates implementation-ready design plan for design-heavy tasks
  ├── executors (parallel where possible):
  │     fullstack-engineer (Codex → Copilot → Claude-native fallback)
  ├── verifier       → runs post-execution verification gate
  ├── final-reviewer → runs Codex final review gate, or Claude-native fallback
  └── git-monitor    → (optional) commit, PR creation, CI/comment monitoring
   │     Optional specialty reviewers (pre-release flow):
   │     security-reviewer, perf-reviewer, a11y-reviewer,
   │     devil-advocate, pm, user-perspective
```

## Flow Engine

The pipeline supports multiple flow templates defined as typed node graphs in `templates/flow-*.yaml`.

### Available Templates

| Template | Use Case | Nodes |
|----------|----------|-------|
| `standard` | Full pipeline (default) | research → plan → plan-review → design? → execute → verify → final-review → ship |
| `review` | Review-only (existing code/PRs) | research → review → verdict |
| `build-verify` | Quick confident changes | plan → execute → verify → ship |
| `pre-release` | Extra review gates | research → plan → plan-review → execute → verify → security → perf → final-review → ship |

### Template Selection

- Default: `standard`
- Override: `/teamwork:flow <name>` command
- Per-repo: `.claude/team.md` `## Flow Template` section

### Gate Verdicts

Verdicts are mechanical, computed from reviewer output markers:
- 🔴 FAIL — halt or loop back per `red_behavior`
- 🟡 ITERATE — loop back for revision within cycle limits
- 🟢 PASS — advance to next node

### Escape Hatches

- `/teamwork:skip` — skip current node
- `/teamwork:pass` — force current gate to green
- `/teamwork:stop` — graceful halt with state preservation
- `/teamwork:goto <node>` — jump to specified node

## Definition of Done

Before planning, three mandatory questions establish acceptance criteria:

1. **What does "done" look like?** — observable outcomes
2. **How will we verify it?** — runnable commands or test cases
3. **How will we evaluate quality?** — quality standards

Criteria are auto-inferred from codebase context (`package.json`, `Makefile`, CI config, `CLAUDE.md`) when not provided. Finalized criteria are written to plan files and included in every executor prompt.

## Workflow

Operational guardrails (always on):
- Keep active sub-agents bounded; proactively close completed agents before spawning new ones.
- If spawn fails due thread/resource limits, close stale agents and retry once; if still failing, stop and report delegation failure.
- Treat verifier/final-review output as stale after any code-changing repair; re-run both gates on fresh evidence.
- Keep an explicit automatic-repair counter and stop at one repair cycle; if still failing, return `needs_manual_fix`.
- Emit executor evidence in the final summary: `task_id -> agent_id -> status`.
- Use portable shell commands in prompts and snippets (avoid assumptions like `timeout` availability).

### 1) Validate plugin readiness

```bash
# Check which plugins are available
CODEX_SCRIPT=$(find ~/.claude/plugins -name "codex-companion.mjs" 2>/dev/null | head -1)
COPILOT_SCRIPT=$(find ~/.claude/plugins -name "copilot-companion.mjs" 2>/dev/null | head -1)

[ -n "$CODEX_SCRIPT" ]   && node "$CODEX_SCRIPT"   setup --json 2>/dev/null && CODEX_OK=true   || CODEX_OK=false
[ -n "$COPILOT_SCRIPT" ] && node "$COPILOT_SCRIPT" setup --json 2>/dev/null && COPILOT_OK=true || COPILOT_OK=false
```

Fallback policy:
- Both installed -> follow plan executor annotations (codex/copilot)
- Copilot unavailable + Codex available -> fullstack-engineer uses Codex plugin
- Codex unavailable + Copilot available -> force copilot; review gates fallback to Claude-native when needed
- Both unavailable -> full Claude-native fallback (lead selects model)

### 2) Read repo team config

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
cat "$REPO_ROOT/.claude/team.md" 2>/dev/null
```

If `.claude/team.md` exists, read:

- Executor routing overrides
- Preferred review mode (`review` or `adversarial-review`)
- Preferred verification commands (`## Verification`)
- Model config (`## Model Config` with `### Primary` / `### Secondary`) — per-agent model overrides with two-tier resolution

### 3) Delegate orchestration to `team-lead`

**HARD STOP — mandatory Agent delegation:**
- Spawn `team-lead` immediately via `Agent`. Do not proceed with any other action.
- Do not implement user code directly in the skill entry.
- Do not use `Write`, `Edit`, or any file-mutating tool before or after spawning `team-lead`.
- If `Agent` delegation fails, report the failure and stop — never fall back to local implementation.
- After `team-lead` returns, proceed to Step 4 (report only). No further implementation steps.

Pass:

```text
Agent: team-lead
Prompt: <user's description>
        Routing preferences: <from .claude/team.md, or "use defaults">
        Model config: <from .claude/team.md ## Model Config, or "no model overrides">
```

Let `team-lead` run:

1. `team-lead` delegates research-stage orchestration to `research-lead`
2. `team-lead` chooses fallback strategy from plugin availability
3. if full Claude fallback is selected, `team-lead` chooses model (`haiku|sonnet|opus`)
4. `research-lead` runs scope split + backend routing + researcher dispatch
   - splits scopes and classifies `research_kind` (`code|web`)
   - dispatches one or more `researcher` agents (parallel when independent)
   - routes backend by policy when both plugins are available:
     - code scopes -> Codex
     - web scopes -> Copilot Claude path
   - each scope returns a minimal navigation map; oversized areas must be split
5. `research-lead` consolidates outputs (`ok|partial|research_unavailable`) into one brief
6. optional readiness loop: `research-lead` can call `planner` in `mode: probe`; if info is insufficient, dispatch targeted `researcher` supplement scopes
7. `planner` creates the plan using the consolidated brief
8. `plan-reviewer` reviews and iterates plan quality (Codex or Claude-native fallback)
9. when design is explicitly required, `designer` creates a design plan before coding
10. `fullstack-engineer` implements approved tasks (auto-selects best available backend)
11. `verifier` runs required checks before completion
   - verifier may reuse cached verification only on exact repo+command key match
12. `final-reviewer` runs final review (Codex or Claude-native fallback)
13. `git-monitor` (optional) commits changes, creates PR, monitors CI and PR comments

### 4) Report outcome

Return:

- research split strategy and consolidated result summary (or `research_unavailable`)
- fallback strategy and selected model (when Claude fallback is used)
- plan path
- modified files grouped by executor
- failed/skipped tasks
- verification result with command evidence
- final review result with key findings
- executor evidence (task ids, agent ids)
- boundary-violation notes (if any)
- follow-up actions
- model config applied (role → model mappings used, or "no overrides")

## Per-Repo Customization

Drop a `.claude/team.md` in the repo to override defaults:

```markdown
## Executor Routing
- *.swift, *.m → copilot
- *.ts, *.tsx  → codex
- tests/**     → codex

## Review Mode
default: adversarial-review

## Verification
- npm run lint
- npm test

## Model Config

### Primary
default: claude-sonnet-4
researcher: claude-haiku-4.5
plan-reviewer: gpt-5.2-codex
fullstack-engineer: claude-sonnet-4
final-reviewer: gpt-5.2-codex
verifier: claude-haiku-4.5

### Secondary
default: claude-haiku-4.5
fullstack-engineer: claude-haiku-4.5
```

Optionally provide project-specific agent prompts in `.claude/agents/`:

- `.claude/agents/researcher.md`
- `.claude/agents/research-lead.md`
- `.claude/agents/designer.md`
- `.claude/agents/fullstack-engineer.md`
- `.claude/agents/verifier.md`
- `.claude/agents/final-reviewer.md`

Project-level agents automatically take priority over global ones.

## Executor Routing

Routing is determined by task weight/rigor (not file type) and can be overridden per-repo via `.claude/team.md`. Only two valid executor values: `codex` and `copilot`.

| Executor | Task Types |
|----------|------------|
| `codex` | Rigorous or heavy tasks: complex algorithms, security-sensitive code, auth/authz, data migrations, strict correctness, large-scale refactors, critical business logic |
| `copilot` | All other tasks: UI changes, simple features, scripts, config, exploratory code, docs, straightforward bug fixes |

## Constraints

- All execution tasks route to `fullstack-engineer`.
- `researcher` is a planning support role and does not execute coding tasks.
- Research splitting and parallelization are decided by `team-lead`, not by researcher/planner.
- Runtime fallback may override plan executor annotation based on plugin availability.
- Require review pass before any execution phase.
- Require designer stage for tasks that explicitly require design output before execution.
- Require verification pass (or explicit `needs_manual_verification`) before claiming completion.
- Require final review pass (or explicit `needs_manual_review`) before claiming completion.
- Keep planner/reviewer/designer scoped to plan/design files; avoid direct project-code edits there.
- Keep executor prompts concrete: scope, dependencies, verification.
- After any code-changing repair, previous verifier/final-review results are invalid and must be refreshed.
- Keep automatic repair loops bounded to one cycle; escalate instead of silently continuing beyond budget.
- Verify plan hash before each execution step (tamper protection).
- Enforce repair budget via code-level `enforce_repair_budget()`, not prompt-level.
- Pipeline state file (`.claude/pipeline-state.json`) is ephemeral — never commit to git.
- Respect flow template cycle limits (per-node, per-edge, and total steps).

## Shipped Agents

- `team-lead.md`
- `researcher.md`
- `research-lead.md`
- `planner.md`
- `plan-reviewer.md`
- `designer.md`
- `fullstack-engineer.md`
- `verifier.md`
- `final-reviewer.md`
- `git-monitor.md`
- `pm.md`
- `security-reviewer.md`
- `devil-advocate.md`
- `a11y-reviewer.md`
- `perf-reviewer.md`
- `user-perspective.md`

Install manually when needed:

```bash
cp agents/*.md ~/.claude/agents/
```
