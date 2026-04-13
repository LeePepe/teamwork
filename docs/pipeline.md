# Pipeline

The teamwork pipeline is a directed graph of stages that transforms a user task description into shipped code. Each stage is handled by a dedicated agent. The pipeline enforces quality gates before advancing.

## Stage Overview

```
research → plan → plan-review → [design] → execute → verify → final-review → ship
```

The `design` stage is optional and activated only when the task explicitly requires design output (UX flow, API contract, architecture design).

## Stages

### 1. Research

**Agent**: `research-lead` + `researcher(s)`

`research-lead` receives the task from `team-lead`, decides the scope split strategy, selects a backend per scope, and dispatches one or more `researcher` agents (in parallel when scopes are independent).

Scope routing when both plugins are available:
- `research_kind=code` → Codex backend (stable, accurate code investigation)
- `research_kind=web` → Copilot Claude path (open-ended web synthesis)
- Mixed scopes are split into separate code/web scopes before dispatch

Each `researcher` returns a scoped navigation map with target areas, entry files, and dependency edges. Oversized areas are split into smaller sub-areas to keep context minimal.

`research-lead` consolidates outputs into a single planning brief with status: `ok`, `partial`, or `research_unavailable`. It may call `planner` in `mode: probe` to check for gaps and dispatch targeted supplemental researcher scopes if needed.

**Output**: consolidated research brief, `research_status`, optional `planning_readiness` and `remaining_gaps`

### 2. Plan

**Agent**: `planner`

`planner` receives the research brief and produces a plan file at `.claude/plan/<slug>.md`. The plan has YAML frontmatter (`title`, `project`, `branch`, `status`, `created`, `size`, `tasks`) and a task list. Each task has `id`, `title`, `size`, `parallel_group`, `executor: codex|copilot`, `status: pending|done`.

Before writing the plan, `planner` establishes acceptance criteria:
1. Uses `acceptance_criteria` from `team-lead` if provided
2. Auto-infers from codebase context (`package.json`, `Makefile`, CI config, `CLAUDE.md`)
3. If no inference is possible, prompts the three Definition of Done questions

After plan creation, `team-lead` computes the plan hash via `plan_hash()` and initializes pipeline state via `init_pipeline_state()`.

**Output**: `.claude/plan/<slug>.md` with executor-annotated tasks

### 3. Plan Review

**Agent**: `plan-reviewer`

`plan-reviewer` reads the plan and verifies it against the plan hash (tamper check). It runs in one of two modes:
- `review`: standard quality review
- `adversarial-review`: adversarial challenge of assumptions, blind spots, and complexity

Backend routing:
- Codex plugin available → Codex review
- Codex unavailable → Claude-native review

The reviewer loops (up to `max_review_loops`) until the plan passes or the cycle limit is hit. Gate verdicts:
- 🟢 PASS → advance to design or execute
- 🟡 ITERATE → revise plan and re-review
- 🔴 FAIL → halt pipeline

**Output**: review verdict, annotated plan (if revised)

### 4. Design (Optional)

**Agent**: `designer`

Activated when the task explicitly requires design output before coding. `designer` produces:
- Design goals and non-goals
- Assumptions and constraints
- Alternatives considered and selected approach
- Interface/contract details (API shapes, component boundaries, data flow)
- Implementation sequencing guidance for executors

`team-lead` passes `design_plan_path` and `executor_handoff` constraints to `fullstack-engineer` when this stage is used.

**Output**: design plan file, `design_status: ready`, executor handoff constraints

### 5. Execute

**Agent**: `fullstack-engineer`

`fullstack-engineer` implements tasks from the approved plan. Before starting, `team-lead` verifies the plan hash (`verify_plan_hash()`) and checks for oscillation (`detect_oscillation()`).

Tasks in the same `parallel_group` run in parallel; different groups run sequentially by dependency order.

Backend selection order:
1. `codex-companion.mjs` (if present and task annotated `executor: codex`)
2. `copilot-companion.mjs` (if present and task annotated `executor: copilot`)
3. Claude-native fallback (always available)

**Output**: modified project files, task completion evidence

### 6. Verify

**Agent**: `verifier`

`verifier` runs post-execution verification commands. Command resolution order:
1. Commands from `.claude/team.md` `## Verification`
2. Task-level verification commands from the plan
3. If none found: return `needs_manual_verification`

Cache behavior: `verifier` builds a cache key from repo state + verification command set. An exact cache hit may be reused; a miss runs commands and writes the result.

`verifier` also verifies the plan hash before running. If tamper is detected, returns `tamper_detected: true` without running commands.

Gate verdicts:
- 🟢 PASS → advance to final-review
- 🟡 ITERATE → trigger one repair round (budget-limited)
- `needs_manual_verification` → continue with warning

### 7. Final Review

**Agent**: `final-reviewer`

Runs a final quality review on the working tree after all verification passes.

Backend routing:
- Codex available → Codex review
- Codex unavailable → Claude-native review

Validates that acceptance criteria are addressed. Includes per-criterion pass/fail in output.

Gate verdicts:
- 🟢 PASS → advance to ship/git-monitor
- 🟡 ITERATE → trigger one repair round (budget-limited)
- `needs_manual_review` → continue with warning

### 8. Ship (git-monitor)

**Agent**: `git-monitor` (optional)

Runs after final-review passes when real file changes exist. Handles:
- Reading commit/PR format from `.claude/team.md` `## Notes` and `CLAUDE.md`
- Staging and committing changes
- Creating a PR to the base branch
- Monitoring CI and PR comments
- Calling `cleanup_pipeline_state()` after successful commit

**Output**: commit SHA, PR URL, CI status

## Flow Templates

Flow templates are YAML files in `templates/flow-*.yaml`. Each defines a directed graph with typed nodes and conditional edges.

### Node Types

| Type | Description |
|------|-------------|
| `discussion` | Research / discussion stages |
| `build` | Plan or design creation |
| `review` | Review/evaluation stages; supports `max_cycles` |
| `execute` | Implementation stages |
| `gate` | Pass/fail decision points |

### Available Templates

| Template | Use Case | Max Steps | Nodes |
|----------|----------|-----------|-------|
| `standard` | Full pipeline (default) | 15 | research → plan → plan-review → design? → execute → verify → final-review → ship |
| `review` | Review-only (existing code/PRs) | 8 | research → review → verdict |
| `build-verify` | Quick confident changes | 10 | plan → execute → verify → ship |
| `pre-release` | Extra security/perf gates | 20 | research → plan → plan-review → execute → verify → security-review → perf-review → final-review → ship |

### Gate Verdicts

Verdicts are computed mechanically by `get_gate_verdict()` from reviewer output text:

| Verdict | Marker | Action |
|---------|--------|--------|
| 🔴 FAIL | `🔴` or `FAIL` | Halt pipeline (`red_behavior: halt`) |
| 🟡 ITERATE | `🟡` or `ITERATE` | Loop back for revision (within `max_cycles`) |
| 🟢 PASS | `🟢` or `PASS` or `LGTM` | Advance to next node |

Priority: red > yellow > green. If no marker found, defaults to yellow.

### Cycle Limits

- `max_pipeline_steps`: total steps across all nodes (default 15 for standard)
- `max_review_loops`: max review iterations (default 3)
- Per-edge `max_cycles`: limits on specific feedback loops (e.g., verify → execute max 1)
- When any limit is hit, pipeline stops with `cycle_limit_reached`

### Template Selection

1. Default: `standard`
2. Command override: `/teamwork:flow <template-name>`
3. Per-repo: `.claude/team.md` `## Flow Template` section

## Escape Hatches

| Command | Action |
|---------|--------|
| `/teamwork:skip` | Skip current node, mark as skipped, advance |
| `/teamwork:pass` | Force current gate to 🟢 PASS |
| `/teamwork:stop` | Graceful halt; save state to `pipeline-state.json` |
| `/teamwork:goto <node>` | Jump to named node (marks intermediate nodes skipped) |

## State Persistence

Pipeline state is tracked in `.claude/pipeline-state.json`.

### State Fields

| Field | Description |
|-------|-------------|
| `plan_path` | Absolute path to the plan file |
| `plan_hash` | SHA256 truncated to 16 hex chars |
| `_write_nonce` | 16-hex random nonce for state transition auth |
| `current_stage` | Current pipeline stage name |
| `completed_stages[]` | List of completed stage names |
| `stage_history[]` | Log of all transitions with timestamps |
| `pipeline_steps` | Counter of total stage transitions |
| `review_loops` | Counter of review iterations |
| `repair_count` | Counter of repair cycles (max 1) |

### Lifecycle

1. `init_pipeline_state()` — called after plan creation; writes initial state, returns nonce
2. `update_stage()` — called after each stage transition; verifies nonce, increments counter
3. `resume_pipeline()` — called at startup; returns `fresh`, `resume`, or `restart`
4. `save_pipeline_state()` — called on `/teamwork:stop`; preserves for cross-session resume
5. `cleanup_pipeline_state()` — called after `git-monitor` succeeds; removes state file

The state file is **ephemeral** and must never be committed to git.

## Tamper Protection

Four mechanisms enforced at shell level via `pipeline-lib.sh`:

### Plan Hash

After `planner` creates a plan, `team-lead` computes `plan_hash()` (SHA256, first 16 chars) and stores it in pipeline state. Before each execution step and in `verifier`/`plan-reviewer`, `verify_plan_hash()` compares the stored hash against the current file hash. A mismatch halts with `tamper_detected`.

### Write Nonce

A 16-hex random nonce is generated at pipeline start via `generate_nonce()`. Every call to `update_stage()` and `enforce_repair_budget()` verifies the nonce via `verify_nonce()`. A mismatch halts with `nonce_mismatch`.

### Repair Budget

`enforce_repair_budget()` reads `repair_count` from state and halts with `repair_budget_exhausted` if `repair_count >= 1`. This prevents infinite repair loops at the code level, not the prompt level.

### Oscillation Detection

`detect_oscillation()` examines the last 6 stage transitions. If an A→B→A→B pattern (4+ alternations) is detected, it warns the user and recommends escape hatch commands.

## Definition of Done

Before planning, three mandatory questions establish acceptance criteria:

1. **What does "done" look like?** — concrete, observable outcomes
2. **How will we verify it?** — runnable commands, test cases, manual checks
3. **How will we evaluate quality?** — code quality, performance, UX standards

Auto-inferred from codebase context when not explicitly provided. Finalized criteria are written to plan files (`## Acceptance Criteria`) and included in every executor prompt and final-reviewer validation.
