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

<!-- Per-agent model assignment using tier + provider. -->
<!-- Resolution: Primary → Secondary → Primary default → Secondary default → omit. -->
<!-- Format: role: tier/provider (one per line). See templates/model-tiers.md for tier definitions. -->
<!-- Providers: claude, openai -->

### Primary

default: tier2/claude
team-lead: tier1/claude
research-lead: tier1/claude
researcher: tier1/openai
planner: tier1/claude
plan-reviewer: tier1/openai
designer: tier2/claude
fullstack-engineer: tier2/claude
verifier: tier4/openai
final-reviewer: tier1/openai
git-monitor: tier4/openai
pm: tier1/openai
security-reviewer: tier1/openai
devil-advocate: tier4/claude
a11y-reviewer: tier1/openai
perf-reviewer: tier1/openai
user-perspective: tier2/claude

### Secondary

default: tier4/claude
planner: tier4/claude
fullstack-engineer: tier4/claude
pm: tier4/claude
security-reviewer: tier4/claude
devil-advocate: tier4/claude
a11y-reviewer: tier4/claude
perf-reviewer: tier4/claude
user-perspective: tier4/claude


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

## Notes

<!-- Context for the planner and team-lead about this repo -->
