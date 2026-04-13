# Team Config

> Copy this file to `.claude/team.md` in your repo to customize teamwork routing.
> The team-lead and planner read this file before starting.

## Executor Routing

<!-- Override default routing. Only two executors: codex and copilot. -->
<!--
Examples:
- *.swift, *.m, *.xib → copilot
- *.ts, *.tsx, *.js   → codex
- src/ui/**           → copilot
- src/api/**          → codex
- tests/**            → codex
- *.py, *.sh          → copilot
-->

## Review Mode

<!-- Options: review, adversarial-review -->
default: review

## Verification

<!-- Optional post-execution verification commands (run in repo root). -->
<!--
Examples:
- npm run lint
- npm test
- pnpm -r test
- go test ./...
-->

## Model Config

<!-- Per-agent model override with two-tier resolution. -->
<!-- team-lead resolves: Primary → Secondary → Primary default → Secondary default → omit. -->
<!-- Format: role: model-id (one per line). -->

### Primary

default: claude-sonnet-4.6
team-lead: claude-opus-4.6
research-lead: claude-opus-4.6
researcher: gpt-5.4
planner: claude-opus-4.6
plan-reviewer: gpt-5.4
designer: claude-sonnet-4.6
fullstack-engineer: claude-sonnet-4.6
verifier: gpt-5.1
final-reviewer: gpt-5.4
git-monitor: gpt-5.1
pm: gpt-5.4
security-reviewer: gpt-5.4
devil-advocate: claude-haiku-4.5
a11y-reviewer: gpt-5.4
perf-reviewer: gpt-5.4
user-perspective: claude-sonnet-4.6

### Secondary

default: claude-haiku-4.5
planner: claude-haiku-4.5
fullstack-engineer: claude-haiku-4.5
pm: claude-haiku-4.5
security-reviewer: claude-haiku-4.5
devil-advocate: claude-haiku-4.5
a11y-reviewer: claude-haiku-4.5
perf-reviewer: claude-haiku-4.5
user-perspective: claude-haiku-4.5


## Definition of Done

<!-- Answer these three questions before planning begins. -->
<!-- Leave blank to auto-infer from codebase context. -->

<!-- What does "done" look like? -->
<!-- How will we verify it? -->
<!-- How will we evaluate quality? -->

## Flow Template

<!-- Override default flow template selection. Options: standard, review, build-verify, pre-release -->
<!-- default: standard -->

## Specialty Reviewers

<!-- Uncomment roles to include in review stages. -->
<!-- These are invoked during pre-release flow or adversarial-review mode. -->
<!--
- security-reviewer
- perf-reviewer
- a11y-reviewer
- devil-advocate
- pm
- user-perspective
-->

## Model Tiers

<!-- Four autonomy tiers. team-lead uses this to understand each model's capability ceiling. -->
<!-- Tier 1: Full autonomy — can make independent architectural decisions, orchestrate pipelines, replan on failure -->
<!-- Tier 2: Scoped autonomy — given a defined scope, can explore and decide within boundaries -->
<!-- Tier 3: Task execution — completes well-defined tasks reliably, follows instructions precisely -->
<!-- Tier 4: Mechanical — runs scripts, parses output, checks lint/test results, no creative decisions -->

### Claude Models

| Tier | Model | Capability |
|------|-------|------------|
| 1 | `claude-opus-4.6` | Full autonomy: orchestration, complex planning, multi-step reasoning |
| 1 | `claude-opus-4.6-1m` | Full autonomy: same as opus-4.6 with 1M context window (Internal) |
| 2-3 | `claude-sonnet-4.6` | Scoped autonomy to task execution: design, implementation, review, focused evaluation |
| 4 | `claude-haiku-4.5` | Mechanical: script parsing, lint checks, structured output, fast/cheap |

### GPT / Codex Models

| Tier | Model | Capability |
|------|-------|------------|
| 1 | `gpt-5.4` | Full autonomy: strongest reasoning, complex multi-step tasks |
| 1 | `gpt-5.2` | Full autonomy: strong general reasoning |
| 2 | `gpt-5.3-codex` | Scoped autonomy: optimized for code generation and review |
| 2 | `gpt-5.1` | Scoped autonomy: reliable within defined boundaries |
| 3 | `gpt-5.4-mini` | Task execution: fast, cost-effective for well-defined tasks |
| 3 | `gpt-5-mini` | Task execution: lightweight, follows instructions |
| 4 | `gpt-4.1` | Mechanical: script parsing, lint checks, structured output |

### Agent → Tier Mapping

| Tier | Agents | Rationale |
|------|--------|-----------|
| 1 | team-lead, research-lead, planner | Orchestration, strategic decisions, plan creation |
| 2 | fullstack-engineer, designer, plan-reviewer, final-reviewer | Scoped implementation, design, quality judgment |
| 3 | researcher, pm, security-reviewer, a11y-reviewer, perf-reviewer, user-perspective, devil-advocate | Focused evaluation within expertise domain |
| 4 | verifier, git-monitor | Run commands, parse results, report pass/fail |

## Notes

<!-- Context for the planner and team-lead about this repo -->
