---
name: teamwork
description: Multi-agent pipeline for complex tasks — research, plan, review, execute, verify, and ship. Supports Codex/Copilot/Claude fallback routing.
---

# Teamwork Skill

Run a structured multi-agent pipeline: team-lead decides research split, one or more researchers gather context for planner, planner writes a plan, plan-reviewer gates quality, executors implement approved tasks, verifier confirms checks, and final-reviewer performs final code review.

## Dependencies

Plugins are optional but recommended:

- **[codex-plugin-cc](https://github.com/openai/codex-plugin-cc)** for Codex rescue/review integration
- **[copilot-plugin-cc](https://github.com/LeePepe/copilot-plugin-cc)** for local Copilot rescue integration

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
```

Natural language trigger:

```text
Use teamwork to implement <feature>
```

Activation safety:
- Only activate this skill for explicit teamwork intent (`/teamwork:task ...` or clear request to "use teamwork").
- Do not activate for casual chat, greetings, or unrelated prompts.
- If the user does not explicitly trigger teamwork, normal Claude execution may run directly without `team-lead`/subagents.

> To install or check status, use `/teamwork:setup` (available after installing this plugin).

## Pipeline

```text
team-lead
  ├── progressive load guides
  │     guide A: research stage  → load researcher only
  │     guide B: plan stage      → load planner + plan-reviewer only
  │     guide C: execution stage → load executors/gates only when needed
  ├── researcher(s)  → lead-decided split, parallel when independent, backend: copilot|codex|claude
  │                    outputs are merged into one brief for planner
  ├── planner        → writes .claude/plan/<slug>.md with executor annotations
  ├── plan-reviewer  → reviews plan (review or adversarial-review)
  ├── executors (parallel where possible):
  │     executor: codex   → codex-coder
  │     executor: copilot → copilot
  │     fallback: claude  → claude-coder
  ├── verifier       → runs post-execution verification gate
  ├── final-reviewer → runs Codex final review gate, or Claude-native fallback
  └── git-monitor    → (optional) commit, PR creation, CI/comment monitoring
```

## Workflow

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

Hard requirement:
- Skill entry does orchestration only.
- Do not implement user code directly in the skill entry.
- Delegate execution to `team-lead` first, then report `team-lead` pipeline results.

Pass:

```text
Agent: team-lead
Prompt: <user's description>
        Routing preferences: <from .claude/team.md, or "use defaults">
```

Let `team-lead` run:

1. `team-lead` decides a research split strategy
2. `team-lead` chooses fallback strategy from plugin availability
3. if full Claude fallback is selected, `team-lead` chooses model (`haiku|sonnet|opus`)
4. one or more `researcher` agents run scoped research with selected backend (parallel when independent)
   - code read/search tasks are owned by `researcher`
   - each scope returns a minimal navigation map; oversized areas must be split
5. `team-lead` consolidates research outputs (`ok|partial|research_unavailable`) into one brief
6. `planner` creates the plan using the consolidated brief
7. `plan-reviewer` reviews and iterates plan quality (Codex or Claude-native fallback)
8. executors implement approved tasks (Codex/Copilot/Claude fallback)
9. `verifier` runs required checks before completion
   - verifier may reuse cached verification only on exact repo+command key match
10. `final-reviewer` runs final review (Codex or Claude-native fallback)
11. `git-monitor` (optional) commits changes, creates PR, monitors CI and PR comments

### 4) Report outcome

Return:

- research split strategy and consolidated result summary (or `research_unavailable`)
- fallback strategy and selected model (when Claude fallback is used)
- plan path
- modified files grouped by executor
- failed/skipped tasks
- verification result with command evidence
- final review result with key findings
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
- Require verification pass (or explicit `needs_manual_verification`) before claiming completion.
- Require final review pass (or explicit `needs_manual_review`) before claiming completion.
- Keep planner and reviewer scoped to plan files; avoid direct project-code edits there.
- Keep executor prompts concrete: scope, dependencies, verification.

## Shipped Agents

- `team-lead.md`
- `researcher.md`
- `planner.md`
- `plan-reviewer.md`
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
