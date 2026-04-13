# Model Tiers

Four autonomy tiers define each model's capability ceiling.
`team-lead` uses this file to understand what level of autonomy a model can handle.

## Tier Definitions

| Tier | Autonomy Level | Description |
|------|----------------|-------------|
| 1 | Full autonomy | Independent architectural decisions, orchestrate pipelines, replan on failure |
| 2 | Scoped autonomy | Given a defined scope, can explore and decide within boundaries |
| 3 | Task execution | Completes well-defined tasks reliably, follows instructions precisely |
| 4 | Mechanical | Runs scripts, parses output, checks lint/test results, no creative decisions |

## Claude Models

| Tier | Model | Capability |
|------|-------|------------|
| 1 | `claude-opus-4.6` | Full autonomy: orchestration, complex planning, multi-step reasoning |
| 1 | `claude-opus-4.6-1m` | Full autonomy: same as opus-4.6 with 1M context window (Internal) |
| 2-3 | `claude-sonnet-4.6` | Scoped autonomy to task execution: design, implementation, review, focused evaluation |
| 4 | `claude-haiku-4.5` | Mechanical: script parsing, lint checks, structured output, fast/cheap |

## GPT / Codex Models

| Tier | Model | Capability |
|------|-------|------------|
| 1-2 | `gpt-5.4` | Full to scoped autonomy: strongest reasoning, complex multi-step tasks, code review |
| 3 | `gpt-5.3-codex` | Task execution: optimized for code generation, follows defined tasks precisely |
| 4 | `gpt-5.4-mini` | Mechanical: script parsing, lint checks, structured output, fast/cheap |

## Agent → Tier Mapping

| Tier | Agents | Rationale |
|------|--------|-----------|
| 1 | team-lead, research-lead, planner | Orchestration, strategic decisions, plan creation |
| 2 | fullstack-engineer, designer, plan-reviewer, final-reviewer | Scoped implementation, design, quality judgment |
| 3 | researcher, pm, security-reviewer, a11y-reviewer, perf-reviewer, user-perspective, devil-advocate | Focused evaluation within expertise domain |
| 4 | verifier, git-monitor | Run commands, parse results, report pass/fail |
