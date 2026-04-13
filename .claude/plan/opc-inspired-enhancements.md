---
title: "OPC-Inspired Teamwork Enhancements: Tamper Protection, Digraph Flow, DoD, State Persistence, Tests, and Enriched Roles"
project: /Users/tianpli/Development/planning-team-skill
branch: main
status: draft
created: 2025-07-25
size: large
reviewed: true
review_rounds: 2
review_mode: review
review_backend: claude
tasks:
  # ── PG-0: Shared Infrastructure (sequential prerequisite) ──────────────
  - id: T01
    title: "Create pipeline-lib.sh — shared shell functions for tamper, state, and flow"
    size: large
    parallel_group: pg-0
    executor: codex
    status: pending
  # ── PG-1: New Agent Files (fully independent, parallel) ────────────────
  - id: T02
    title: "Create agents/pm.md"
    size: small
    parallel_group: pg-1
    executor: copilot
    status: pending
  - id: T03
    title: "Create agents/security-reviewer.md"
    size: small
    parallel_group: pg-1
    executor: copilot
    status: pending
  - id: T04
    title: "Create agents/devil-advocate.md"
    size: small
    parallel_group: pg-1
    executor: copilot
    status: pending
  - id: T05
    title: "Create agents/a11y-reviewer.md"
    size: small
    parallel_group: pg-1
    executor: copilot
    status: pending
  - id: T06
    title: "Create agents/perf-reviewer.md"
    size: small
    parallel_group: pg-1
    executor: copilot
    status: pending
  - id: T07
    title: "Create agents/user-perspective.md"
    size: small
    parallel_group: pg-1
    executor: copilot
    status: pending
  # ── PG-2: Flow Templates (independent, parallel) ──────────────────────
  - id: T08
    title: "Create templates/flow-standard.yaml"
    size: small
    parallel_group: pg-2
    executor: copilot
    status: pending
  - id: T09
    title: "Create templates/flow-review.yaml"
    size: small
    parallel_group: pg-2
    executor: copilot
    status: pending
  - id: T10
    title: "Create templates/flow-build-verify.yaml"
    size: small
    parallel_group: pg-2
    executor: copilot
    status: pending
  - id: T11
    title: "Create templates/flow-pre-release.yaml"
    size: small
    parallel_group: pg-2
    executor: copilot
    status: pending
  # ── PG-3: Core Agent Modifications (after PG-0; parallel within — different files) ──
  - id: T12
    title: "Update agents/team-lead.md — tamper, digraph flow, DoD, state persistence"
    size: large
    parallel_group: pg-3
    executor: codex
    status: pending
  - id: T13
    title: "Update agents/planner.md — DoD pre-flight questions, acceptance criteria, plan hash"
    size: medium
    parallel_group: pg-3
    executor: codex
    status: pending
  - id: T14
    title: "Update agents/plan-reviewer.md — hash verification, gate verdicts"
    size: medium
    parallel_group: pg-3
    executor: codex
    status: pending
  - id: T15
    title: "Update agents/verifier.md — tamper checksum, state cache integration"
    size: medium
    parallel_group: pg-3
    executor: codex
    status: pending
  - id: T16
    title: "Update agents/final-reviewer.md — DoD acceptance criteria validation"
    size: small
    parallel_group: pg-3
    executor: copilot
    status: pending
  - id: T17
    title: "Update agents/git-monitor.md — state cleanup after commit"
    size: small
    parallel_group: pg-3
    executor: copilot
    status: pending
  # ── PG-4: Documentation and Config Updates (after PG-1, PG-2, PG-3) ──
  - id: T18
    title: "Update AGENTS.md — add new agent rows"
    size: small
    parallel_group: pg-4
    executor: copilot
    status: pending
  - id: T19
    title: "Update SKILL.md — flow engine, DoD, new agents"
    size: medium
    parallel_group: pg-4
    executor: codex
    status: pending
  - id: T20
    title: "Update CLAUDE.md — tamper rules, flow engine, state persistence"
    size: medium
    parallel_group: pg-4
    executor: codex
    status: pending
  - id: T21
    title: "Update templates/team.md — DoD section, specialty role config"
    size: small
    parallel_group: pg-4
    executor: copilot
    status: pending
  - id: T22
    title: "Update scripts/setup.sh — register new agents, test support"
    size: medium
    parallel_group: pg-4
    executor: codex
    status: pending
  - id: T23
    title: "Bump version in VERSION, plugin.json (both plugins), and SKILL.md metadata"
    size: small
    parallel_group: pg-4
    executor: copilot
    status: pending
  - id: T25
    title: "Create escape-hatch command files: commands/skip.md, pass.md, stop.md, goto.md, flow.md"
    size: medium
    parallel_group: pg-4
    executor: copilot
    status: pending
  - id: T26
    title: "Update .gitignore — add .claude/pipeline-state.json"
    size: small
    parallel_group: pg-4
    executor: copilot
    status: pending
  # ── PG-5: Test Harness (after PG-0, PG-3) ────────────────────────────
  - id: T24
    title: "Create test/test-pipeline.sh — comprehensive shell test suite"
    size: large
    parallel_group: pg-5
    executor: codex
    status: pending
---

## Background

The teamwork skill currently provides a linear pipeline (research → plan → review → execute → verify → final-review → git-monitor) with agent delegation. It lacks runtime integrity guarantees, flexible flow control, explicit definition of done, state persistence across sessions, automated tests, and specialty reviewer roles.

This plan introduces six major features inspired by OPC (Orchestrated Pipeline Control) patterns, translated from OPC's Node.js harness model into the Markdown+Shell architecture used by this skill repo.

## Goals

1. **Tamper Protection (F1)**: Guarantee plan integrity via SHA256 hashing, nonce-guarded state transitions, review independence checks, oscillation detection, and enforced repair budgets at the code level.
2. **Digraph-based Flow Engine (F2)**: Replace the implicit linear pipeline with typed node graphs supporting multiple flow templates, mechanical gate verdicts, cycle limits, escape hatches, and ASCII visualization.
3. **Definition of Done (F3)**: Require three mandatory questions before planning begins, auto-infer acceptance criteria from codebase context, embed finalized criteria in plan files and every executor prompt.
4. **State Persistence and Recovery (F4)**: Track pipeline state in `.claude/pipeline-state.json` with stage tracking, plan hash, and nonce. Support resume, chain validation, and graceful termination.
5. **Automated Tests (F5)**: Shell-based test harness validating all new infrastructure: tamper detection, state transitions, hash verification, nonce validation, oscillation detection, review independence, and flow template routing.
6. **Enriched Role Library (F6)**: Six new specialty reviewer/advisory agents following the existing YAML frontmatter + Markdown body convention.

## Risks and Considerations

- **Cross-feature coupling in team-lead.md**: F1, F2, F3, and F4 all modify `agents/team-lead.md`. T12 handles all four features in one pass to avoid merge conflicts — this makes T12 the largest and most critical task.
- **Shell portability**: All shell functions in `pipeline-lib.sh` must use POSIX-compatible constructs. Hash computation should use a portability shim that prefers `shasum -a 256` (macOS) but falls back to `sha256sum` (Linux). The `mktemp` utility is used only in tests, not production.
- **Backward compatibility**: Existing pipelines that don't use the new features should continue to work unchanged. The state file, nonce, and hash features should be additive (opt-in or auto-initialized) rather than breaking.
- **Flow template complexity**: We deliberately keep templates simpler than OPC's 13-node full-stack template. The most complex template (`flow-standard.yaml`) should have ≤8 nodes.
- **Version strategy**: Adding 6 agents bumps MINOR per policy. Both plugin.json files (`.claude-plugin/plugin.json` at `0.6.3` and `.codex-plugin/plugin.json` at `0.1.0`) get +6 minor bumps → `0.12.3` and `0.7.0` respectively. `skills/teamwork/SKILL.md` metadata.version must match `.claude-plugin/plugin.json` (`0.12.3`). `VERSION` file must match `.codex-plugin/plugin.json` (`0.7.0`).
- **Ephemeral state file**: `.claude/pipeline-state.json` must never be committed. It must be added to `.gitignore`.
- **Escape-hatch commands**: The flow engine introduces `/teamwork:skip`, `/teamwork:pass`, `/teamwork:stop`, `/teamwork:goto`, and `/teamwork:flow` — each requires a corresponding `commands/*.md` file to be registered as a slash command.
- **Test isolation**: Tests use `mktemp -d` for scratch directories and `trap` for cleanup. They must not modify repo files.
- **Research status**: Research was comprehensive; no missing scopes identified. Design patterns and file mappings are well-established in the research brief.

## Subtask Details

---

### T01: Create `scripts/pipeline-lib.sh` — Shared Shell Functions
**Feature**: F1 (Tamper), F2 (Flow), F4 (State)
**Executor**: codex
**Dependencies**: None (foundation for all other tasks)

This is the core infrastructure library. All tamper, state, and flow functions live here so agents can source them.

- [ ] Create `scripts/pipeline-lib.sh` with `set -euo pipefail` and `#!/usr/bin/env bash`
- [ ] Implement SHA256 portability shim — detect `shasum` (macOS) vs `sha256sum` (Linux):
  ```bash
  _sha256() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"
    elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"
    else echo "ERROR: no SHA256 tool found" >&2; return 1; fi
  }
  ```
- [ ] Implement `plan_hash()` — compute SHA256 truncated to 16 hex chars:
  ```bash
  plan_hash() { _sha256 "$1" | cut -c1-16; }
  ```
- [ ] Implement `verify_plan_hash()` — compare stored hash in state file against current plan hash; return 0 on match, 1 on mismatch with diagnostic message to stderr
- [ ] Implement `generate_nonce()` — produce 16-hex random nonce:
  ```bash
  generate_nonce() { od -An -tx1 -N8 /dev/urandom | tr -d ' \n'; }
  ```
- [ ] Implement `verify_nonce()` — compare provided nonce against `_write_nonce` in state file
- [ ] Implement `init_pipeline_state()` — create `.claude/pipeline-state.json` with fields:
  - `plan_path`, `plan_hash`, `_write_nonce`, `current_stage`, `completed_stages[]`, `pending_stages[]`, `stage_history[]`, `created_at`, `pipeline_steps: 0`, `review_loops: 0`
- [ ] Implement `update_stage()` — transition to a new stage with nonce verification; append to `stage_history[]`; increment `pipeline_steps`; enforce `max_pipeline_steps: 15`
- [ ] Implement `detect_oscillation()` — scan last 6 entries of `stage_history[]` for A→B→A→B pattern (4+ alternations); return warning message if detected
- [ ] Implement `check_review_independence()` — accept two reviewer output strings, compare via diff; warn if outputs are identical (>95% similarity)
- [ ] Implement `enforce_repair_budget()` — read `repair_count` from state; if ≥1, return error; else increment and write back
- [ ] Implement `get_gate_verdict()` — parse reviewer output for 🔴/🟡/🟢 markers:
  - 🔴 or `FAIL` → return `red`
  - 🟡 or `ITERATE` → return `yellow`
  - 🟢 or `PASS` or `LGTM` → return `green`
- [ ] Implement `load_flow_template()` — read a YAML flow template file from `templates/` directory; parse nodes and edges into shell-friendly format (key=value lines)
- [ ] Implement `render_flow_ascii()` — given current node, completed nodes, and pending nodes, render ASCII pipeline visualization:
  ```
  [✅ research] → [✅ plan] → [▶ review] → [○ execute] → [○ verify] → [○ final-review]
  ```
- [ ] Implement `resume_pipeline()` — detect existing `.claude/pipeline-state.json`; validate plan hash chain integrity; return `resume|restart|fresh`
- [ ] Implement `save_pipeline_state()` — atomic write of state JSON (write to `.tmp` then `mv`)
- [ ] Implement `cleanup_pipeline_state()` — remove state file (called by git-monitor after successful commit)

**File scope**: `scripts/pipeline-lib.sh` (new file)

**Verification**:
```bash
bash -n scripts/pipeline-lib.sh  # syntax check
source scripts/pipeline-lib.sh && type plan_hash && type generate_nonce && type init_pipeline_state && type detect_oscillation && type render_flow_ascii
```

---

### T02: Create `agents/pm.md`
**Feature**: F6 (Enriched Roles)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `agents/pm.md` with YAML frontmatter:
  ```yaml
  ---
  name: pm
  description: Product manager perspective — validates user value, prioritization, and scope clarity.
  tools: Read, Glob, Grep, Bash
  ---
  ```
- [ ] Write body sections: Role Overview, Expertise, When to Include, Input, Workflow, Constraints, Output Contract, Anti-Patterns
- [ ] Role focuses on: user story validation, scope creep detection, prioritization guidance, acceptance criteria quality
- [ ] Output contract: structured verdict with `relevance`, `scope_clarity`, `priority_alignment`, `recommendations[]`

**File scope**: `agents/pm.md` (new file)

**Verification**: `head -5 agents/pm.md | grep -q 'name: pm'`

---

### T03: Create `agents/security-reviewer.md`
**Feature**: F6 (Enriched Roles)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `agents/security-reviewer.md` with YAML frontmatter:
  ```yaml
  ---
  name: security-reviewer
  description: Security-focused code reviewer — identifies vulnerabilities, auth issues, and data exposure risks.
  tools: Read, Glob, Grep, Bash
  ---
  ```
- [ ] Write body sections: Role Overview, Expertise (OWASP Top 10, auth/authz, input validation, secrets management, dependency vulnerabilities), When to Include, Input, Workflow, Constraints, Output Contract, Anti-Patterns
- [ ] Output contract: `severity: critical|high|medium|low`, `findings[]` with `category`, `location`, `description`, `remediation`

**File scope**: `agents/security-reviewer.md` (new file)

**Verification**: `head -5 agents/security-reviewer.md | grep -q 'name: security-reviewer'`

---

### T04: Create `agents/devil-advocate.md`
**Feature**: F6 (Enriched Roles)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `agents/devil-advocate.md` with YAML frontmatter:
  ```yaml
  ---
  name: devil-advocate
  description: Adversarial challenger — stress-tests assumptions, finds edge cases, and proposes simpler alternatives.
  tools: Read, Glob, Grep, Bash
  ---
  ```
- [ ] Write body sections: Role Overview, Expertise (assumption challenging, edge case discovery, alternative architectures, complexity reduction), When to Include, Input, Workflow, Constraints, Output Contract, Anti-Patterns
- [ ] Output contract: `challenges[]` with `assumption`, `counter_argument`, `risk_level`, `alternative`

**File scope**: `agents/devil-advocate.md` (new file)

**Verification**: `head -5 agents/devil-advocate.md | grep -q 'name: devil-advocate'`

---

### T05: Create `agents/a11y-reviewer.md`
**Feature**: F6 (Enriched Roles)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `agents/a11y-reviewer.md` with YAML frontmatter:
  ```yaml
  ---
  name: a11y-reviewer
  description: Accessibility reviewer — checks WCAG compliance, screen reader compatibility, and inclusive design patterns.
  tools: Read, Glob, Grep, Bash
  ---
  ```
- [ ] Write body sections: Role Overview, Expertise (WCAG 2.1 AA/AAA, ARIA patterns, keyboard navigation, color contrast, screen reader testing), When to Include, Input, Workflow, Constraints, Output Contract, Anti-Patterns
- [ ] Output contract: `wcag_level`, `findings[]` with `criterion`, `element`, `issue`, `fix`

**File scope**: `agents/a11y-reviewer.md` (new file)

**Verification**: `head -5 agents/a11y-reviewer.md | grep -q 'name: a11y-reviewer'`

---

### T06: Create `agents/perf-reviewer.md`
**Feature**: F6 (Enriched Roles)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `agents/perf-reviewer.md` with YAML frontmatter:
  ```yaml
  ---
  name: perf-reviewer
  description: Performance reviewer — identifies bottlenecks, inefficient algorithms, memory issues, and scalability risks.
  tools: Read, Glob, Grep, Bash
  ---
  ```
- [ ] Write body sections: Role Overview, Expertise (algorithmic complexity, memory profiling, I/O optimization, caching strategies, database query performance, bundle size), When to Include, Input, Workflow, Constraints, Output Contract, Anti-Patterns
- [ ] Output contract: `severity`, `findings[]` with `category`, `location`, `impact`, `recommendation`

**File scope**: `agents/perf-reviewer.md` (new file)

**Verification**: `head -5 agents/perf-reviewer.md | grep -q 'name: perf-reviewer'`

---

### T07: Create `agents/user-perspective.md`
**Feature**: F6 (Enriched Roles)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `agents/user-perspective.md` with YAML frontmatter:
  ```yaml
  ---
  name: user-perspective
  description: End-user advocate — evaluates UX quality, error handling clarity, onboarding friction, and user journey coherence.
  tools: Read, Glob, Grep, Bash
  ---
  ```
- [ ] Write body sections: Role Overview, Expertise (UX heuristics, error message quality, onboarding flow, user journey mapping, feedback loops), When to Include, Input, Workflow, Constraints, Output Contract, Anti-Patterns
- [ ] Output contract: `ux_score`, `findings[]` with `journey_stage`, `issue`, `severity`, `improvement`

**File scope**: `agents/user-perspective.md` (new file)

**Verification**: `head -5 agents/user-perspective.md | grep -q 'name: user-perspective'`

---

### T08: Create `templates/flow-standard.yaml`
**Feature**: F2 (Digraph Flow)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `templates/flow-standard.yaml` defining the standard full pipeline flow:
  ```yaml
  name: standard
  description: Full research-plan-review-execute-verify-review pipeline
  max_pipeline_steps: 15
  max_review_loops: 3
  nodes:
    - id: research
      type: discussion
      label: "Research"
    - id: plan
      type: build
      label: "Plan"
    - id: plan-review
      type: review
      label: "Plan Review"
      max_cycles: 3
    - id: design
      type: build
      label: "Design"
      optional: true
    - id: execute
      type: execute
      label: "Execute"
    - id: verify
      type: gate
      label: "Verify"
    - id: final-review
      type: review
      label: "Final Review"
    - id: ship
      type: gate
      label: "Ship"
  edges:
    - from: research
      to: plan
    - from: plan
      to: plan-review
    - from: plan-review
      to: design
      condition: "design_required"
    - from: plan-review
      to: execute
      condition: "!design_required"
    - from: design
      to: execute
    - from: execute
      to: verify
    - from: verify
      to: final-review
      condition: "green"
    - from: verify
      to: execute
      condition: "yellow"
      max_cycles: 1
    - from: final-review
      to: ship
      condition: "green"
    - from: final-review
      to: execute
      condition: "yellow"
      max_cycles: 1
  # red verdict on any gate/review node → pipeline halt (no edge needed;
  # absence of a matching edge means the flow engine stops with error state)
  red_behavior: halt
  ```

**File scope**: `templates/flow-standard.yaml` (new file)

**Verification**: `python3 -c "import yaml; yaml.safe_load(open('templates/flow-standard.yaml'))" 2>/dev/null || python3 -c "import json; print('YAML check skipped, file exists:', __import__('os').path.isfile('templates/flow-standard.yaml'))"`

---

### T09: Create `templates/flow-review.yaml`
**Feature**: F2 (Digraph Flow)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `templates/flow-review.yaml` — lightweight review-only pipeline:
  ```yaml
  name: review
  description: Review-only flow for existing code or PRs
  max_pipeline_steps: 8
  max_review_loops: 3
  nodes:
    - id: research
      type: discussion
      label: "Research"
    - id: review
      type: review
      label: "Code Review"
      max_cycles: 3
    - id: verdict
      type: gate
      label: "Verdict"
  edges:
    - from: research
      to: review
    - from: review
      to: verdict
  ```

**File scope**: `templates/flow-review.yaml` (new file)

**Verification**: `test -f templates/flow-review.yaml`

---

### T10: Create `templates/flow-build-verify.yaml`
**Feature**: F2 (Digraph Flow)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `templates/flow-build-verify.yaml` — build and verify without full review:
  ```yaml
  name: build-verify
  description: Quick build-and-verify flow for confident changes
  max_pipeline_steps: 10
  max_review_loops: 2
  nodes:
    - id: plan
      type: build
      label: "Plan"
    - id: execute
      type: execute
      label: "Execute"
    - id: verify
      type: gate
      label: "Verify"
    - id: ship
      type: gate
      label: "Ship"
  edges:
    - from: plan
      to: execute
    - from: execute
      to: verify
    - from: verify
      to: ship
      condition: "green"
    - from: verify
      to: execute
      condition: "yellow"
      max_cycles: 1
  ```

**File scope**: `templates/flow-build-verify.yaml` (new file)

**Verification**: `test -f templates/flow-build-verify.yaml`

---

### T11: Create `templates/flow-pre-release.yaml`
**Feature**: F2 (Digraph Flow)
**Executor**: copilot
**Dependencies**: None

- [ ] Create `templates/flow-pre-release.yaml` — pre-release with extra review gates:
  ```yaml
  name: pre-release
  description: Pre-release flow with security and performance review gates
  max_pipeline_steps: 15
  max_review_loops: 3
  nodes:
    - id: research
      type: discussion
      label: "Research"
    - id: plan
      type: build
      label: "Plan"
    - id: plan-review
      type: review
      label: "Plan Review"
      max_cycles: 3
    - id: execute
      type: execute
      label: "Execute"
    - id: verify
      type: gate
      label: "Verify"
    - id: security-review
      type: review
      label: "Security Review"
    - id: perf-review
      type: review
      label: "Perf Review"
    - id: final-review
      type: review
      label: "Final Review"
    - id: ship
      type: gate
      label: "Ship"
  edges:
    - from: research
      to: plan
    - from: plan
      to: plan-review
    - from: plan-review
      to: execute
    - from: execute
      to: verify
    - from: verify
      to: security-review
      condition: "green"
    - from: verify
      to: execute
      condition: "yellow"
      max_cycles: 1
    - from: security-review
      to: perf-review
    - from: perf-review
      to: final-review
    - from: final-review
      to: ship
      condition: "green"
    - from: final-review
      to: execute
      condition: "yellow"
      max_cycles: 1
  ```

**File scope**: `templates/flow-pre-release.yaml` (new file)

**Verification**: `test -f templates/flow-pre-release.yaml`

---

### T12: Update `agents/team-lead.md` — Core Pipeline Enhancements
**Feature**: F1 (Tamper), F2 (Digraph Flow), F3 (DoD), F4 (State)
**Executor**: codex
**Dependencies**: T01 (pipeline-lib.sh must exist)

This is the most critical task — it integrates all four core features into the orchestrator.

- [ ] Add `## Pipeline Infrastructure` section referencing `scripts/pipeline-lib.sh` as the source for all tamper/state/flow shell functions
- [ ] Add `## Tamper Protection` section:
  - After planner creates plan, compute and store `plan_hash` via `plan_hash()` in pipeline state
  - Before each execution step, call `verify_plan_hash()` — halt if mismatch
  - Generate nonce at pipeline start via `generate_nonce()`, store in state file
  - All state transitions must verify nonce via `verify_nonce()`
  - Add review independence check: when two reviewers are used (adversarial-review), compare outputs via `check_review_independence()`
  - Integrate `detect_oscillation()` — check after each stage transition; if triggered, warn user and offer escape (skip/stop/goto)
  - Replace prompt-level repair budget with code-level `enforce_repair_budget()` call
- [ ] Add `## Flow Engine` section:
  - On pipeline start, select flow template based on task characteristics or user override
  - Default template: `flow-standard.yaml`; support `/teamwork:flow <template-name>` override
  - Load flow template via `load_flow_template()`
  - Track current position in flow graph; enforce per-edge, per-node, and total step cycle limits
  - After each stage transition, call `render_flow_ascii()` and include in stage summary
  - Support escape hatches:
    - `/teamwork:skip` — skip current node (mark as skipped, advance to next)
    - `/teamwork:pass` — force current gate to green
    - `/teamwork:stop` — graceful halt with state preservation
    - `/teamwork:goto <node>` — jump to specified node (with warning)
  - Compute mechanical gate verdicts via `get_gate_verdict()` — parse 🔴/🟡/🟢 from reviewer output
- [ ] Add `## Definition of Done` section:
  - Before calling planner, present three mandatory questions:
    1. "What does 'done' look like?"
    2. "How will we verify it?"
    3. "How will we evaluate quality?"
  - Auto-infer answers from codebase context (check for `package.json`, `Makefile`, `.github/workflows/`, `CLAUDE.md`, existing test directories)
  - Pass finalized acceptance criteria to planner as `acceptance_criteria` in prompt
  - Include acceptance criteria in every executor prompt as `## Acceptance Criteria` section
  - At final-review, validate that acceptance criteria are addressed
- [ ] Add `## State Persistence` section:
  - At pipeline start, call `resume_pipeline()` to detect existing state
  - If existing state found: validate chain integrity, offer `continue|restart`
  - Initialize state via `init_pipeline_state()` for fresh pipelines
  - After each stage, call `save_pipeline_state()` for atomic persistence
  - On graceful termination (`/teamwork:stop`), save state for later resume
- [ ] Update `## Team` to include new specialty roles: `pm`, `security-reviewer`, `devil-advocate`, `a11y-reviewer`, `perf-reviewer`, `user-perspective`
- [ ] Update `## Workflow` to integrate state init/save/resume at appropriate steps
- [ ] Add new specialty roles to progressive loading when pre-release or adversarial flows are selected

**File scope**: `agents/team-lead.md`

**Verification**:
```bash
grep -q 'Tamper Protection' agents/team-lead.md
grep -q 'Flow Engine' agents/team-lead.md
grep -q 'Definition of Done' agents/team-lead.md
grep -q 'State Persistence' agents/team-lead.md
grep -q 'pipeline-lib.sh' agents/team-lead.md
grep -q 'security-reviewer' agents/team-lead.md
```

---

### T13: Update `agents/planner.md` — DoD and Plan Hash
**Feature**: F3 (DoD), F1 (Tamper)
**Executor**: codex
**Dependencies**: T01 (pipeline-lib.sh)

- [ ] Add `## Definition of Done Pre-Flight` section:
  - Before creating the plan, check if `acceptance_criteria` was provided by team-lead
  - If not provided, auto-infer from codebase context:
    - Check for `package.json` → infer `npm test`, `npm run lint`
    - Check for `Makefile` → infer `make test`
    - Check for `.github/workflows/` → infer CI will validate
    - Check for `CLAUDE.md` → extract verification commands
  - Present three questions to fill gaps (or accept team-lead answers)
- [ ] Add `acceptance_criteria` as a new required plan field in frontmatter
- [ ] Add `## Acceptance Criteria` body section in plan file template (after Goals, before Risks)
- [ ] After writing plan file, compute and emit `plan_hash` in output for team-lead to store:
  ```bash
  source scripts/pipeline-lib.sh
  HASH=$(plan_hash "$PLAN_PATH")
  echo "plan_hash: $HASH"
  ```
- [ ] Update `## Required Plan Fields` to include `acceptance_criteria` and `plan_hash`

**File scope**: `agents/planner.md`

**Verification**:
```bash
grep -q 'acceptance_criteria' agents/planner.md
grep -q 'plan_hash' agents/planner.md
grep -q 'Definition of Done' agents/planner.md
```

---

### T14: Update `agents/plan-reviewer.md` — Hash Verification and Gate Verdicts
**Feature**: F1 (Tamper), F2 (Digraph Flow)
**Executor**: codex
**Dependencies**: T01 (pipeline-lib.sh)

- [ ] Add plan hash verification at the start of review:
  - Accept `expected_plan_hash` from team-lead
  - Before reading plan content, verify hash matches via `verify_plan_hash()`
  - If mismatch, halt review and return `tamper_detected: true` with diagnostic
- [ ] Update review output to include mechanical gate verdict:
  - End review output with exactly one verdict marker: 🔴 FAIL, 🟡 ITERATE, or 🟢 PASS
  - `🔴 FAIL` = fundamental issues requiring re-planning
  - `🟡 ITERATE` = actionable issues, plan can be revised in-place
  - `🟢 PASS` = plan is ready for execution (equivalent to current `LGTM`)
- [ ] Update `## Output Contract` to document the verdict marker format
- [ ] Add `plan_hash_verified: true|false` to output metadata

**File scope**: `agents/plan-reviewer.md`

**Verification**:
```bash
grep -q 'verify_plan_hash' agents/plan-reviewer.md
grep -q '🔴' agents/plan-reviewer.md
grep -q '🟡' agents/plan-reviewer.md
grep -q '🟢' agents/plan-reviewer.md
```

---

### T15: Update `agents/verifier.md` — Tamper Checksum and State Integration
**Feature**: F1 (Tamper), F4 (State)
**Executor**: codex
**Dependencies**: T01 (pipeline-lib.sh)

- [ ] Add plan hash verification before running verification commands:
  - Accept `expected_plan_hash` from team-lead
  - Call `verify_plan_hash()` — if tamper detected, return `tamper_detected` instead of running checks
- [ ] Integrate with pipeline state for cache:
  - When `.claude/pipeline-state.json` exists, use it as additional cache key component
  - Include `pipeline_nonce` in cache key to prevent cross-pipeline cache reuse
- [ ] Add mechanical gate verdict output:
  - All pass → 🟢 PASS
  - Some fail → 🔴 FAIL
  - No commands → 🟡 ITERATE (needs_manual_verification)
- [ ] Add `plan_hash_verified`, `pipeline_state_used` to output contract

**File scope**: `agents/verifier.md`

**Verification**:
```bash
grep -q 'verify_plan_hash' agents/verifier.md
grep -q 'pipeline-state' agents/verifier.md
grep -q '🟢' agents/verifier.md
```

---

### T16: Update `agents/final-reviewer.md` — DoD Acceptance Criteria Validation
**Feature**: F3 (DoD)
**Executor**: copilot
**Dependencies**: None (uses plan file content, no lib dependency)

- [ ] Add acceptance criteria validation to review workflow:
  - Read `## Acceptance Criteria` section from plan file
  - For each criterion, assess whether the implementation addresses it
  - Include per-criterion pass/fail in review output
- [ ] Add mechanical gate verdict output: 🔴 FAIL / 🟡 ITERATE / 🟢 PASS
- [ ] Update output contract to include `acceptance_criteria_met: true|false|partial` and `criteria_results[]`

**File scope**: `agents/final-reviewer.md`

**Verification**:
```bash
grep -q 'Acceptance Criteria' agents/final-reviewer.md
grep -q 'acceptance_criteria_met' agents/final-reviewer.md
```

---

### T17: Update `agents/git-monitor.md` — State Cleanup After Commit
**Feature**: F4 (State)
**Executor**: copilot
**Dependencies**: None (references pipeline-state.json path only)

- [ ] After successful commit and push, clean up pipeline state:
  - Check for `.claude/pipeline-state.json`
  - If exists and all tasks are done, remove it (same as plan file cleanup)
  - Log state cleanup in output notes
- [ ] Add `pipeline_state_cleaned: true|false` to output contract
- [ ] Ensure state file is NOT staged/committed (it's ephemeral runtime state)

**File scope**: `agents/git-monitor.md`

**Verification**:
```bash
grep -q 'pipeline-state' agents/git-monitor.md
grep -q 'pipeline_state_cleaned' agents/git-monitor.md
```

---

### T18: Update `AGENTS.md` — Add New Agent Rows
**Feature**: F6 (Enriched Roles)
**Executor**: copilot
**Dependencies**: T02–T07 (agent files must exist)

- [ ] Add 6 new rows to the Agent Inventory table:

| Agent | Role | May Edit Files? | Source Path | Purpose |
|-------|------|----------------|-------------|---------|
| `pm` | Advisory | No | `agents/pm.md` | Product manager perspective; validates user value and scope |
| `security-reviewer` | Quality | No | `agents/security-reviewer.md` | Security-focused code review; identifies vulnerabilities |
| `devil-advocate` | Advisory | No | `agents/devil-advocate.md` | Adversarial challenger; stress-tests assumptions |
| `a11y-reviewer` | Quality | No | `agents/a11y-reviewer.md` | Accessibility review; WCAG compliance checks |
| `perf-reviewer` | Quality | No | `agents/perf-reviewer.md` | Performance review; identifies bottlenecks and scalability risks |
| `user-perspective` | Advisory | No | `agents/user-perspective.md` | End-user advocate; evaluates UX quality |

**File scope**: `AGENTS.md`

**Verification**:
```bash
grep -c 'agents/' AGENTS.md  # should be 18 (12 existing + 6 new)
```

---

### T19: Update `SKILL.md` — Flow Engine, DoD, New Agents, Commands
**Feature**: F2 (Flow), F3 (DoD), F6 (Roles)
**Executor**: codex
**Dependencies**: T08–T11 (flow templates), T02–T07 (agents), T12 (team-lead changes), T25 (command files)

- [ ] Add `## Flow Engine` section after Pipeline, documenting:
  - Available flow templates: `standard`, `review`, `build-verify`, `pre-release`
  - How to select a flow template (auto-detection or `/teamwork:flow <name>`)
  - Escape hatches: `/teamwork:skip`, `/teamwork:pass`, `/teamwork:stop`, `/teamwork:goto`
  - Mechanical gate verdicts (🔴/🟡/🟢)
- [ ] Add `## Definition of Done` section documenting:
  - Three mandatory questions
  - Auto-inference from codebase context
  - Acceptance criteria in plan files
- [ ] Update `## Shipped Agents` to include all 6 new agents
- [ ] Update `## Pipeline` ASCII diagram to show optional specialty review nodes
- [ ] Update `## Triggers` to list new slash commands (`/teamwork:skip`, `/teamwork:pass`, `/teamwork:stop`, `/teamwork:goto`, `/teamwork:flow`)
- [ ] Update `## Constraints` to include tamper protection rules and state persistence behavior

**File scope**: `SKILL.md`

**Verification**:
```bash
grep -q 'Flow Engine' SKILL.md
grep -q 'Definition of Done' SKILL.md
grep -q 'security-reviewer' SKILL.md
grep -q 'pm.md' SKILL.md
```

---

### T20: Update `CLAUDE.md` — Tamper Rules, Flow Engine, State Persistence
**Feature**: F1 (Tamper), F2 (Flow), F4 (State)
**Executor**: codex
**Dependencies**: T01 (pipeline-lib.sh), T12 (team-lead changes)

- [ ] Add `### Tamper Protection` subsection under Architecture:
  - Plan hash: SHA256 truncated to 16 hex, verified before each execution step
  - Write nonce: 16-hex random nonce in pipeline state, verified on every state transition
  - Oscillation detection: A→B→A→B over 4+ cycles triggers warning
  - Repair budget: code-enforced single cycle, not just prompt-level
  - Review independence: adversarial reviews must be genuinely distinct
- [ ] Add `### Flow Engine` subsection under Architecture:
  - Flow templates in `templates/flow-*.yaml`
  - Node types: discussion, build, review, execute, gate
  - Cycle limits: max_pipeline_steps, max_review_loops, per-edge max_cycles
  - Escape hatches
- [ ] Add `### State Persistence` subsection under Architecture:
  - State file: `.claude/pipeline-state.json` (ephemeral, not committed)
  - Resume protocol: detect existing state → validate hash chain → offer continue/restart
  - Graceful termination preserves state
- [ ] Update `### Basic Navigation Map` to include new files:
  - `scripts/pipeline-lib.sh` under Install/runtime layout
  - `templates/flow-*.yaml` under new Flow templates category
  - `test/test-pipeline.sh` under new Testing category
- [ ] Add `.claude/pipeline-state.json` to the note about ephemeral/non-committed files

**File scope**: `CLAUDE.md`

**Verification**:
```bash
grep -q 'Tamper Protection' CLAUDE.md
grep -q 'pipeline-state.json' CLAUDE.md
grep -q 'pipeline-lib.sh' CLAUDE.md
grep -q 'flow-standard' CLAUDE.md
```

---

### T21: Update `templates/team.md` — DoD Section, Specialty Role Config
**Feature**: F3 (DoD), F6 (Roles)
**Executor**: copilot
**Dependencies**: None

- [ ] Add `## Definition of Done` section with three question prompts (commented template):
  ```markdown
  ## Definition of Done

  <!-- Answer these three questions before planning begins. -->
  <!-- Leave blank to auto-infer from codebase context. -->

  <!-- What does "done" look like? -->
  <!-- How will we verify it? -->
  <!-- How will we evaluate quality? -->
  ```
- [ ] Add `## Specialty Reviewers` section (commented template):
  ```markdown
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
  ```
- [ ] Add `## Flow Template` section (commented template):
  ```markdown
  ## Flow Template

  <!-- Override default flow template selection. Options: standard, review, build-verify, pre-release -->
  <!-- default: standard -->
  ```

**File scope**: `templates/team.md`

**Verification**:
```bash
grep -q 'Definition of Done' templates/team.md
grep -q 'Specialty Reviewers' templates/team.md
grep -q 'Flow Template' templates/team.md
```

---

### T22: Update `scripts/setup.sh` — Register New Agents, Test Support
**Feature**: F5 (Tests), F6 (Roles)
**Executor**: codex
**Dependencies**: T02–T07 (agents exist)

- [ ] Add new agents to `RUNTIME_AGENTS` array:
  ```bash
  RUNTIME_AGENTS=(research-lead researcher planner plan-reviewer designer codex-coder copilot claude-coder verifier final-reviewer git-monitor pm security-reviewer devil-advocate a11y-reviewer perf-reviewer user-perspective)
  ```
- [ ] Add test harness note to `--check` output:
  ```bash
  echo ""
  echo "Tests:"
  [ -f "$SKILL_DIR/test/test-pipeline.sh" ] \
    && ok "  test harness available: bash test/test-pipeline.sh" \
    || warn "  test harness not found"
  ```
- [ ] Ensure `scripts/pipeline-lib.sh` is copied to skill bundle during install:
  ```bash
  mkdir -p "$SKILL_DEST/scripts"
  cp "$SKILL_DIR/scripts/pipeline-lib.sh" "$SKILL_DEST/scripts/pipeline-lib.sh"
  ```
- [ ] Copy flow templates to skill bundle:
  ```bash
  mkdir -p "$SKILL_DEST/templates"
  for tmpl in "$SKILL_DIR"/templates/flow-*.yaml; do
    [ -f "$tmpl" ] && cp "$tmpl" "$SKILL_DEST/templates/"
  done
  ```

**File scope**: `scripts/setup.sh`

**Verification**:
```bash
bash -n scripts/setup.sh
grep -q 'pm' scripts/setup.sh
grep -q 'security-reviewer' scripts/setup.sh
grep -q 'pipeline-lib.sh' scripts/setup.sh
```

---

### T23: Bump Version
**Feature**: All (release)
**Executor**: copilot
**Dependencies**: All previous tasks

- [ ] Update `VERSION` from `0.1.0` to `0.7.0` (6 new agents = 6 MINOR bumps)
- [ ] Update `.claude-plugin/plugin.json` `version` from `0.6.3` to `0.12.3` (+6 MINOR)
- [ ] Update `.codex-plugin/plugin.json` `version` from `0.1.0` to `0.7.0` (+6 MINOR, matches VERSION)
- [ ] Update `skills/teamwork/SKILL.md` metadata.version to `0.12.3` (must match `.claude-plugin/plugin.json` per CLAUDE.md policy)

**File scope**: `VERSION`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `skills/teamwork/SKILL.md` (metadata line only)

**Verification**:
```bash
cat VERSION  # should show 0.7.0
python3 -c "import json; d=json.load(open('.claude-plugin/plugin.json')); assert d['version']=='0.12.3', d['version']"
python3 -c "import json; d=json.load(open('.codex-plugin/plugin.json')); assert d['version']=='0.7.0', d['version']"
grep -q '0.12.3' skills/teamwork/SKILL.md
```

---

### T25: Create Escape-Hatch Command Files
**Feature**: F2 (Digraph Flow)
**Executor**: copilot
**Dependencies**: T12 (team-lead flow engine must be defined)

The flow engine introduces 5 new slash commands. Each needs a `commands/*.md` file to be registered.

- [ ] Create `commands/skip.md` — `/teamwork:skip` to skip current flow node:
  ```yaml
  ---
  description: Skip the current pipeline node (mark as skipped, advance to next).
  allowed-tools: Bash, Agent
  ---
  ```
  Body: validate flow engine is active, delegate to team-lead with `flow_action: skip`.
- [ ] Create `commands/pass.md` — `/teamwork:pass` to force-pass current gate:
  ```yaml
  ---
  description: Force the current gate to green verdict (escape hatch).
  allowed-tools: Bash, Agent
  ---
  ```
  Body: validate current node is a gate, delegate to team-lead with `flow_action: pass`.
- [ ] Create `commands/stop.md` — `/teamwork:stop` for graceful halt:
  ```yaml
  ---
  description: Gracefully halt the pipeline, preserving state for later resume.
  allowed-tools: Bash, Agent
  ---
  ```
  Body: delegate to team-lead with `flow_action: stop`, confirm state saved.
- [ ] Create `commands/goto.md` — `/teamwork:goto <node>` to jump to a node:
  ```yaml
  ---
  description: Jump to a specific pipeline node (with warning).
  argument-hint: "<node-id>"
  allowed-tools: Bash, Agent
  ---
  ```
  Body: validate node exists in current flow template, warn user, delegate with `flow_action: goto, target: <node>`.
- [ ] Create `commands/flow.md` — `/teamwork:flow <template>` to select flow template:
  ```yaml
  ---
  description: Select a flow template for the current pipeline run.
  argument-hint: "<template-name>"
  allowed-tools: Bash, Agent
  ---
  ```
  Body: validate template exists in `templates/flow-*.yaml`, delegate with `flow_template: <name>`.

**File scope**: `commands/skip.md`, `commands/pass.md`, `commands/stop.md`, `commands/goto.md`, `commands/flow.md` (all new files)

**Verification**:
```bash
for cmd in skip pass stop goto flow; do
  test -f "commands/$cmd.md" || echo "MISSING: commands/$cmd.md"
done
```

---

### T26: Update `.gitignore` — Add Pipeline State File
**Feature**: F4 (State)
**Executor**: copilot
**Dependencies**: None

- [ ] Add `.claude/pipeline-state.json` to `.gitignore` to prevent accidental commits of ephemeral runtime state

**File scope**: `.gitignore`

**Verification**:
```bash
grep -q 'pipeline-state.json' .gitignore
```

---

### T24: Create `test/test-pipeline.sh` — Comprehensive Test Suite
**Feature**: F5 (Tests)
**Executor**: codex
**Dependencies**: T01 (pipeline-lib.sh — tests exercise these functions)

- [ ] Create `test/` directory and `test/test-pipeline.sh` with `#!/usr/bin/env bash` and `set -euo pipefail`
- [ ] Implement test framework functions:
  ```bash
  PASS=0; FAIL=0; TOTAL=0
  assert_eq() {
    TOTAL=$((TOTAL + 1))
    if [ "$1" = "$2" ]; then PASS=$((PASS + 1)); echo "  ✓ $3"
    else FAIL=$((FAIL + 1)); echo "  ✗ $3: expected '$1', got '$2'"; fi
  }
  assert_contains() {
    TOTAL=$((TOTAL + 1))
    if echo "$1" | grep -q "$2"; then PASS=$((PASS + 1)); echo "  ✓ $3"
    else FAIL=$((FAIL + 1)); echo "  ✗ $3: '$2' not found in output"; fi
  }
  assert_file_exists() {
    TOTAL=$((TOTAL + 1))
    if [ -f "$1" ]; then PASS=$((PASS + 1)); echo "  ✓ $2"
    else FAIL=$((FAIL + 1)); echo "  ✗ $2: file not found: $1"; fi
  }
  ```
- [ ] Use `mktemp -d` for test scratch directory with `trap` cleanup
- [ ] Source `scripts/pipeline-lib.sh` for function access
- [ ] **Test Group 1: Plan Hash**
  - Create a dummy plan file, compute hash via `plan_hash()`, verify it's 16 hex chars
  - Modify the plan file, verify hash changes
  - Test `verify_plan_hash()` succeeds with correct hash, fails with incorrect hash
- [ ] **Test Group 2: Nonce**
  - Generate nonce via `generate_nonce()`, verify it's 16 hex chars
  - Generate two nonces, verify they're different
  - Test `verify_nonce()` with matching and non-matching nonces
- [ ] **Test Group 3: State Transitions**
  - Initialize pipeline state via `init_pipeline_state()`
  - Verify state file exists and contains expected fields (using `python3 -c` for JSON field checks)
  - Transition through stages via `update_stage()`, verify `current_stage` and `stage_history` update
  - Test step limit enforcement (attempt >15 transitions)
- [ ] **Test Group 4: Oscillation Detection**
  - Build a stage_history with A→B→A→B pattern, verify `detect_oscillation()` triggers warning
  - Build a normal progression (A→B→C→D), verify no oscillation detected
- [ ] **Test Group 5: Review Independence**
  - Test `check_review_independence()` with identical outputs → warns
  - Test with different outputs → no warning
- [ ] **Test Group 6: Repair Budget**
  - Test `enforce_repair_budget()` succeeds on first call
  - Test it fails on second call (budget=1)
- [ ] **Test Group 7: Gate Verdicts**
  - Test `get_gate_verdict()` with 🔴 → red, 🟡 → yellow, 🟢 → green
  - Test with text markers: `FAIL` → red, `ITERATE` → yellow, `PASS` → green, `LGTM` → green
- [ ] **Test Group 8: Flow Template**
  - Test `load_flow_template()` can parse `templates/flow-standard.yaml`
  - Test `render_flow_ascii()` shows correct markers for various states
- [ ] **Test Group 9: Agent Frontmatter Validation**
  - For each agent file in `agents/`, verify YAML frontmatter contains `name`, `description`, `tools`
  - Verify new agents have additional sections: Expertise, When to Include, Anti-Patterns
- [ ] **Test Group 10: Setup Idempotency**
  - Run `bash scripts/setup.sh --check` and verify exit code
- [ ] Print summary: `echo "Results: $PASS/$TOTAL passed, $FAIL failed"`
- [ ] Exit with code 1 if any test failed

**File scope**: `test/test-pipeline.sh` (new file)

**Verification**:
```bash
bash -n test/test-pipeline.sh  # syntax check
```

---

## Execution Order

```
PG-0 (T01: pipeline-lib.sh)                                       ←  prerequisite
PG-1 (T02–T07: new agents, parallel)                              ←  independent of PG-0
PG-2 (T08–T11: flow templates, parallel)                          ←  independent of PG-0
  ↓  (PG-0, PG-1, PG-2 can all run in parallel)
PG-3 (T12–T17: core agent modifications, parallel within group)   ←  depends on PG-0
  ↓
PG-4 (T18–T23, T25–T26: docs, config, commands, version)         ←  depends on PG-1, PG-2, PG-3
  ↓
PG-5 (T24: test harness)                                          ←  depends on PG-0, PG-3
```

Note: PG-0, PG-1, and PG-2 can all run in parallel since PG-1 and PG-2 have no dependencies on pipeline-lib.sh. PG-3 must wait for PG-0 to complete since those agents reference the library functions. PG-4 must wait for PG-1, PG-2, and PG-3 since it documents/registers their outputs.

## Post-Execution Checklist

After all tasks complete:
1. Run `bash -n scripts/pipeline-lib.sh` — syntax check
2. Run `bash -n scripts/setup.sh` — syntax check
3. Run `bash -n test/test-pipeline.sh` — syntax check
4. Verify all 5 new command files exist in `commands/`
5. Run `bash scripts/setup.sh --repo` — sync installed copies
6. Run `bash test/test-pipeline.sh` — full test suite
7. Verify all 18 agent files have valid YAML frontmatter
8. Verify `.gitignore` contains `pipeline-state.json`
9. Verify all 4 version files are consistent (VERSION, .claude-plugin/plugin.json, .codex-plugin/plugin.json, skills/teamwork/SKILL.md)
10. Commit with: `feat: add tamper protection, digraph flow, DoD, state persistence, tests, 6 specialty agents, and escape-hatch commands`

## Review Log

### Round 1 (Claude-native, review mode)

Backend downgrade: Codex companion was found but hit usage limit; downgraded to Claude-native review.

**8 findings (2 critical, 6 significant):**

1. 🔴 **Missing escape-hatch command files** — T12 introduces `/teamwork:skip`, `/teamwork:pass`, `/teamwork:stop`, `/teamwork:goto`, `/teamwork:flow` but no task creates the corresponding `commands/*.md` files. **Fix**: Added T25 (PG-4) to create all 5 command files.
2. 🔴 **Version strategy gaps** — Plan created divergent target versions and omitted `.codex-plugin/plugin.json`. **Fix**: T23 now covers all 4 version files with consistent strategy; verification checks all 4.
3. 🟡 **Missing `.gitignore` entry** — `.claude/pipeline-state.json` is ephemeral but nothing prevents accidental commit. **Fix**: Added T26 (PG-4) to add it to `.gitignore`.
4. 🟡 **PG-3 header/body mismatch** — YAML comment said "sequential within" but tasks touch different files and are parallel. **Fix**: Comment updated to "parallel within — different files".
5. 🟡 **Flow template missing `red` path** — Gate nodes had `green`/`yellow` edges but undefined `red` behavior. **Fix**: Added `red_behavior: halt` to `flow-standard.yaml` template.
6. 🟡 **T22 false dependency on T24** — T22 (PG-4) listed T24 (PG-5) as dependency, but PG-5 runs after PG-4 and the dependency is not real. **Fix**: Removed T24 from T22's dependencies.
7. 🟡 **Shell portability** — `shasum` unavailable on many Linux distros. **Fix**: Added `_sha256()` portability shim to T01 spec, updated risk section.
8. 🟡 **`.codex-plugin/plugin.json` omitted** — T23 didn't update this file. **Fix**: Added to T23 scope with verification.

**Additional updates**: T19 updated to document new commands in SKILL.md triggers. Execution order and post-execution checklist updated for T25–T26 (now 26 tasks across 6 parallel groups). Risk section expanded with ephemeral state and escape-hatch notes.

### Round 2 (Claude-native, self-review)

Verified all 8 Round 1 fixes are correctly applied. No new issues found. Plan is complete, feasible, and convention-aligned.
