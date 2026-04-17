# Model Tiers

Four autonomy tiers define each model's capability ceiling.
When this file is updated, regenerate the `## Model Config` section in `templates/team.md` with concrete model IDs.

## Tier Definitions

| Tier | Autonomy Level | Description |
|------|----------------|-------------|
| 1 | Full autonomy | Independent architectural decisions, orchestrate pipelines, replan on failure |
| 2 | Scoped autonomy | Given a defined scope, can explore and decide within boundaries |
| 3 | Task execution | Completes well-defined tasks reliably, follows instructions precisely |
| 4 | Mechanical | Runs scripts, parses output, checks lint/test results, no creative decisions |

## Provider Model Map

### Claude

| Tier | Model |
|------|-------|
| 1 | `claude-opus-4.6` |
| 1 | `claude-opus-4.6-1m` (Internal, 1M context) |
| 2-3 | `claude-sonnet-4.6` |
| 4 | `claude-haiku-4.5` |

### OpenAI

| Tier | Model |
|------|-------|
| 1-2 | `gpt-5.4` |
| 3 | `gpt-5.3-codex` |
| 4 | `gpt-5.4-mini` |

## Agent Assignments

| Agent | Tier | Primary Provider | Secondary Provider |
|-------|------|-----------------|-------------------|
| team-lead | 1 | claude | openai |
| planner-lead | 1 | claude | openai |
| linter | 2 | openai | claude |
| plan-reviewer | 1 | openai | claude |
| final-reviewer | 1 | openai | claude |
| designer | 2 | claude | openai |
| fullstack-engineer | 2 | claude | openai |
| researcher | 2 | openai | claude |
| pm | 2 | openai | claude |
| security-reviewer | 2 | openai | claude |
| a11y-reviewer | 2 | openai | claude |
| perf-reviewer | 2 | openai | claude |
| user-perspective | 2 | claude | openai |
| devil-advocate | 4 | claude | openai |
| verifier | 4 | openai | claude |
| git-monitor | 4 | openai | claude |
