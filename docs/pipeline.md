# Pipeline

The teamwork pipeline is a directed graph that transforms a user task into shipped code with explicit governance gates.

## Stage Overview

```
plan (planner-lead) -> plan-review (tech+pm) -> execute -> verify -> pm-review -> final-review -> ship
```

## Stages

### 1. Plan (Unified by `planner-lead`)

**Primary agent**: `planner-lead`

`planner-lead` is the single owner of the planning phase:
- Dispatches `researcher` workers for scoped research (parallel when independent)
- Consolidates findings
- Dispatches `designer` when design output is required
- Dispatches `linter` to define strict architecture lint contract
- Produces the executable plan directly

Lint contract baseline:
- layer order: `Types -> Config -> Repo -> Service -> Runtime -> UI`
- lower layers cannot reverse-depend on upper layers
- lint diagnostics must explain rule rationale and correct refactor direction

**Output**:
- `.claude/plan/<slug>.md`
- `plan_hash`
- `owner_per_task`
- `research_status`
- `design_status`
- `lint_contract_summary`

### 2. Plan Gate (Dual Approval)

**Agents**: `plan-reviewer` + `pm`

Plan must pass both gates:
- `plan-reviewer`: technical feasibility and execution safety
- `pm` (`mode: plan-gate`): product value, scope, acceptance criteria quality

If either returns `🟡 ITERATE`, plan is revised and re-gated within cycle limits.

### 3. Execute

**Agent**: `fullstack-engineer`

Implements tasks in dependency order; same `parallel_group` tasks may run in parallel.
Backend priority: Copilot -> Claude-native -> Codex (tertiary fallback).

### 4. Verify

**Agent**: `verifier`

Runs verification commands and returns concrete command evidence.
Lint command(s) are mandatory; missing lint evidence prevents passing the delivery gate.

### 5. PM Delivery Gate

**Agent**: `pm` (`mode: delivery-gate`)

PM supervises delivery quality using execution + verification evidence:
- Are acceptance criteria really satisfied?
- Is test evidence sufficient for product risk?

### 6. Final Review Coalition

**Leader**: `final-reviewer`

`final-reviewer` does two things:
1. Runs final code review with backend priority: Copilot -> Claude-native -> Codex (tertiary)
2. Orchestrates specialty reviewers and consolidates verdict:
   - `security-reviewer`
   - `devil-advocate`
   - `a11y-reviewer`
   - `perf-reviewer`
   - `user-perspective`

### 7. Ship

**Agent**: `git-monitor` (optional when code changed)

Commits, opens PR, monitors CI/comments, and cleans pipeline state.

## Flow Templates

Templates are defined in `templates/flow-*.yaml`.

### Available Templates

| Template | Use Case | Core Path |
|----------|----------|-----------|
| `standard` | Default full governance | plan -> plan-review -> execute -> verify -> pm-review -> final-review -> ship |
| `build-verify` | Compact but still fully gated | plan -> plan-review -> execute -> verify -> pm-review -> final-review -> ship |
| `pre-release` | Stricter release checks | standard with tighter cycle budget |
| `review` | Existing code/PR review | research -> final-review -> verdict |

## Gate Semantics

Verdicts are marker-based (`🔴 FAIL`, `🟡 ITERATE`, `🟢 PASS`) and processed by flow rules.

- `🔴 FAIL` -> halt (unless explicitly overridden)
- `🟡 ITERATE` -> bounded repair/revision cycle
- `🟢 PASS` -> advance

## Integrity Controls

Implemented by `scripts/pipeline-lib.sh`:
- Plan hash verification
- Mandatory lint enforcement in verification/CI gate
- Write nonce verification
- Repair budget enforcement
- Oscillation detection
- Persisted state in `.claude/pipeline-state.json`

## Execution Evidence Contract

`team-lead` final output must include:

- `entry_delegate_role: team-lead`
- `execution_ledger` with one row per stage (`team-lead`, `planner-lead`, `plan-reviewer`, `pm(plan-gate)`, `fullstack-engineer`, `verifier`, `pm(delivery-gate)`, `final-reviewer`, optional `git-monitor`)
- Per-row fields: `stage`, `delegated_agent_role`, `agent_handle`, `status`, `model`, `tools`, `skills`, `evidence`
- `missing_evidence` list (must be explicit; never silently omit unknowns)

Command handlers must not perform post-delegation implementation or verification takeover. They only orchestrate delegation and summarize `team-lead` evidence.
