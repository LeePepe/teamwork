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

<!-- Per-agent model override. When set, team-lead passes the `model` parameter to task() when spawning each agent. -->
<!-- Format: role: model-id (one per line). Use `default` as fallback for unlisted roles. -->
<!-- Omit this section or leave it empty to use default model selection (no override). -->

default: claude-sonnet-4
research-lead: claude-haiku-4.5
researcher: claude-haiku-4.5
planner: claude-sonnet-4
plan-reviewer: claude-sonnet-4
designer: claude-sonnet-4
codex-coder: claude-sonnet-4
copilot: claude-sonnet-4
claude-coder: claude-sonnet-4
verifier: claude-haiku-4.5
final-reviewer: claude-sonnet-4
git-monitor: claude-haiku-4.5

## Notes

<!-- Context for the planner and team-lead about this repo -->
