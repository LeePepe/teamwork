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
  │     executor: codex   → codex-coder
  │     executor: copilot → copilot
  │     fallback: claude  → claude-coder
  ├── verifier       → runs post-execution verification gate
  ├── final-reviewer → runs Codex final review gate, or Claude-native fallback
  └── git-monitor    → (optional) commit, PR creation, CI/comment monitoring
```

## Workflow

Operational guardrails (always on):
- Keep active sub-agents bounded; proactively close completed agents before spawning new ones.
- If spawn fails due thread/resource limits, close stale agents and retry once; if still failing, stop and report delegation failure.
- Treat verifier/final-review output as stale after any code-changing repair; re-run both gates on fresh evidence.
- Keep an explicit automatic-repair counter and stop at one repair cycle; if still failing, return `needs_manual_fix`.
- Emit executor evidence in the final summary: `task_id -> executor -> agent_id -> status`.
- If `copilot=true` and there are `executor: copilot` tasks, dispatch at least one to `copilot`; otherwise report why not.
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
- Both installed -> tasks routed per plan annotation (default behavior)
- Copilot unavailable + Codex available -> all plugin-backed tasks fallback to Codex
- Codex unavailable + Copilot available -> use Copilot for research/execution; review gates fallback to Claude-native when needed
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
10. executors implement approved tasks (Codex/Copilot/Claude fallback)
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
- copilot invocation evidence (`invoked: true|false`, tasks, agent ids)
- boundary-violation notes (if any)
- follow-up actions

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
```

Optionally provide project-specific agent prompts in `.claude/agents/`:

- `.claude/agents/researcher.md`
- `.claude/agents/research-lead.md`
- `.claude/agents/designer.md`
- `.claude/agents/codex-coder.md`
- `.claude/agents/copilot.md`
- `.claude/agents/claude-coder.md`
- `.claude/agents/verifier.md`
- `.claude/agents/final-reviewer.md`

Project-level agents automatically take priority over global ones.

## Executor Routing Defaults

Route by task weight and rigor requirement, not by language or file type:

| Executor | When to use |
|----------|-------------|
| `codex` | Rigorous or heavy tasks: complex algorithms, security-sensitive code, auth/authz, data migrations, strict correctness requirements, large-scale refactors with many interdependencies, critical business logic, tasks requiring deep analysis before coding |
| `copilot` | All other tasks: UI changes, simple feature additions, scripts, configuration, exploratory/experimental code, documentation, straightforward bug fixes, lightweight tooling |

## Constraints

- Keep task routing values to `codex` or `copilot`.
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

## Shipped Agents

- `team-lead.md`
- `researcher.md`
- `research-lead.md`
- `planner.md`
- `plan-reviewer.md`
- `designer.md`
- `codex-coder.md`
- `copilot.md`
- `claude-coder.md`
- `verifier.md`
- `final-reviewer.md`
- `git-monitor.md`

Install manually when needed:

```bash
cp agents/*.md ~/.claude/agents/
```
