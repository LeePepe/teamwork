# Agent Reference

Full per-agent reference for all 16 agents in the teamwork skill. For an inventory table, see `AGENTS.md`. For pipeline stage context, see `docs/pipeline.md`.

---

## team-lead

**Role**: Orchestration  
**Source**: `agents/team-lead.md`  
**Tools**: Read, Glob, Bash, Agent  
**May edit project files**: No

### Purpose

Pipeline orchestrator. Delegates all work to sub-agents. Never edits project files directly.

### Inputs

- User task description
- Plugin availability flags (`codex=true|false`, `copilot=true|false`)
- Routing preferences from `.claude/team.md`
- Model config map from `.claude/team.md ## Model Config`

### Outputs

Final summary including: fallback strategy, research summary, design stage status, completed/failed/skipped tasks, modified files, verifier/final-review results, git-monitor result, executor evidence, boundary violations, model config applied.

### Key Behaviors

- Sources `pipeline-lib.sh` for tamper protection and state management
- Reads `.claude/team.md` for executor routing, review mode, verification commands, model config
- Resolves agent model using two-tier lookup (Primary → Secondary → Primary default → Secondary default)
- Calls `resume_pipeline()` at startup; offers resume/restart if stale state exists
- Runs Definition of Done pre-flight before calling planner
- Computes `plan_hash()` after plan creation; calls `init_pipeline_state()`
- Verifies plan hash (`verify_plan_hash()`) and oscillation (`detect_oscillation()`) before each execution step
- Calls `enforce_repair_budget()` before any repair round
- Calls `render_flow_ascii()` after each stage transition
- Calls `cleanup_pipeline_state()` after `git-monitor` succeeds
- Applies model lookup for every agent spawn via `task()`
- Keeps active delegated agents bounded (target <=4, hard cap <=6)
- If delegation fails, reports failure — does not implement locally as fallback

---

## research-lead

**Role**: Research  
**Source**: `agents/research-lead.md`  
**Tools**: Read, Glob, Bash, Agent  
**May edit project files**: No

### Purpose

Research orchestrator. Splits research scopes, dispatches researcher agents, and consolidates findings into one planning brief for `team-lead`.

### Inputs

- User task
- Routing preferences and plugin availability
- Optional fallback constraints and `claude_model`
- Model config map

### Outputs

- `research_split_strategy`: scope list with `research_kind` and backend per scope
- `consolidated_brief`: merged findings from all researchers
- `research_status`: `ok`, `partial`, or `research_unavailable`
- Optional: `planning_readiness`, `remaining_gaps`

### Key Behaviors

- Decides scope split (small/simple: one scope; medium/large: multiple independent scopes)
- Classifies each scope as `code` or `web` for backend routing
- Routes code scopes to Codex (stability/accuracy); web scopes to Copilot Claude path (open-ended synthesis)
- Dispatches researcher agents in parallel when scopes are independent
- May call `planner` in `mode: probe` to check for information gaps; dispatches supplemental scopes if needed
- Consolidates all researcher outputs into a single brief for `planner`

---

## researcher

**Role**: Research  
**Source**: `agents/researcher.md`  
**Tools**: Bash, Read, Glob, Grep  
**May edit project files**: No

### Purpose

Single-scope research worker. Backend is assigned by `research-lead` per model focus policy. Runs in parallel when multiple independent scopes are dispatched.

### Inputs

- Assigned research scope and exact question boundaries
- Backend instruction: `backend: copilot|codex|claude`
- `research_kind: code|web`
- Optional `claude_model`

### Outputs

Scoped research result with:
- Navigation map: target areas, entry files, dependency edges
- Findings relevant to the assigned scope
- Structured output for `research-lead` consolidation

### Key Behaviors

- Locks scope boundaries at start to prevent scope creep
- Always reads `.claude/team.md` when present
- Reads `AGENTS.md` and `CLAUDE.md` only when needed for navigation/conventions
- Produces a scoped navigation map before diving into content
- Splits oversized areas into smaller sub-areas to keep context minimal
- Tries Codex plugin (`codex-companion.mjs`) or Copilot plugin (`copilot-companion.mjs`) if available; falls back to Claude-native research
- Avoids broad whole-repo dumps; maps only what planner/executors need

---

## planner

**Role**: Planning  
**Source**: `agents/planner.md`  
**Tools**: Read, Write, Glob, Grep, Bash, Agent  
**May edit project files**: Plan files only

### Purpose

Converts user requirements and research brief into an executable plan file for the team.

### Inputs

- User requirements
- Consolidated research brief
- Optional `acceptance_criteria` from `team-lead`
- Mode: `plan` (default) or `probe`

### Outputs

- `mode: plan`: plan file at `.claude/plan/<slug>.md` with YAML frontmatter and task list
- `mode: probe`: assessment of planning readiness and list of missing research

### Plan File Format

YAML frontmatter: `title`, `project`, `branch`, `status: draft|approved`, `created`, `size: small|medium|large`, `acceptance_criteria`

Tasks list — each task: `id`, `title`, `size`, `parallel_group`, `executor: codex|copilot`, `status: pending|done`

Tasks in the same `parallel_group` run in parallel; different groups run sequentially.

### Key Behaviors

- In `mode: probe`: assesses planning readiness without writing a plan file
- Runs Definition of Done pre-flight: uses provided criteria, auto-infers from codebase, or prompts three DoD questions
- Annotates each task with `executor: codex` (rigorous/heavy) or `executor: copilot` (all other)
- Writes acceptance criteria to plan as `## Acceptance Criteria` section and frontmatter field
- Supports plan updates when called with an existing plan path

---

## plan-reviewer

**Role**: Planning  
**Source**: `agents/plan-reviewer.md`  
**Tools**: Read, Write, Bash  
**May edit project files**: Plan files only

### Purpose

Reviews a plan file, revises it if needed, and loops until quality passes or cycle limit is hit.

### Inputs

- Plan file path
- Mode: `review` or `adversarial-review`
- Backend: `codex` or `claude`; optional `claude_model`
- Optional `expected_plan_hash` for tamper check

### Outputs

- Review verdict (approved, iterate, fail)
- Revised plan file (if iterate)
- `plan_hash_verified: true` (if hash check passes)
- `tamper_detected: true` (if hash mismatch)

### Key Behaviors

- Verifies plan hash via `verify_plan_hash()` if `expected_plan_hash` is provided
- Uses Codex plugin if available; falls back to Claude-native
- In `adversarial-review` mode, challenges assumptions, finds blind spots, and stress-tests the plan
- Loops for revision within `max_review_loops` cycle limit
- Returns `plan_hash_verified: true` on match; halts immediately on mismatch

---

## designer

**Role**: Design  
**Source**: `agents/designer.md`  
**Tools**: Read, Glob, Bash, Write  
**May edit project files**: Plan/design files only

### Purpose

Design specialist for UX/architecture/API design tasks. Produces executable design plans and handoff constraints for executors. Does not edit project source code.

### Inputs

- User requirements
- Consolidated research brief (when available)
- Approved implementation plan path (when available)
- Routing preferences

### Outputs

- Design plan file with: goals, non-goals, assumptions, alternatives considered, selected approach, interface/contract details, implementation sequencing
- `design_status: ready` or clarification questions
- `executor_handoff`: constraints for fullstack-engineer

### Key Behaviors

- Activates only when `team-lead` explicitly routes to designer (design-heavy tasks)
- Reads minimal repo context (team.md, relevant specs, target modules)
- Does not modify project source files
- Pipeline continues only when `design_status=ready`

---

## fullstack-engineer

**Role**: Execution  
**Source**: `agents/fullstack-engineer.md`  
**Tools**: Bash, Read, Write, Glob, Grep  
**May edit project files**: Yes

### Purpose

Unified executor agent. Delegates to the best available plugin (Codex → Copilot) or implements directly via Claude-native fallback. Handles all coding tasks regardless of complexity.

### Inputs

- Plan file path
- Task id and title
- Task goal and file scope
- Constraints/invariants
- Verification requirements
- Optional `claude_model` hint
- Optional `design_plan_path` and `executor_handoff` (when design stage was used)

### Outputs

- Modified project files
- Task completion status and evidence

### Backend Selection

1. Check for `codex-companion.mjs` in `~/.claude/plugins/`
2. Check for `copilot-companion.mjs` in `~/.claude/plugins/`
3. Claude-native fallback (always available)

When overridden by `team-lead` routing policy:
- `codex=true copilot=false`: use Codex plugin for all tasks
- `codex=false copilot=true`: use Copilot plugin for all tasks
- Both unavailable: Claude-native with `claude_model` hint

### Key Behaviors

- Never orchestrates other agents
- Reads the plan file to confirm goal, file scope, and verification criteria
- Reads target files and identifies exact edit scope before writing
- Applies acceptance criteria from plan in all implementations
- When using Claude-native, uses `claude_model` hint to guide depth/reasoning level

---

## verifier

**Role**: Quality  
**Source**: `agents/verifier.md`  
**Tools**: Bash, Read, Glob, Grep  
**May edit project files**: No

### Purpose

Verification gate. Runs required verification commands after execution and reports pass/fail evidence.

### Inputs

- Plan file path
- Project root path
- Optional verification commands from `.claude/team.md`
- Optional completed task list
- Optional `expected_plan_hash`

### Outputs

- Verification result: pass, fail, or `needs_manual_verification`
- Command output evidence
- `plan_hash_verified: true` or `tamper_detected: true`
- Cache key and cache hit/miss status

### Key Behaviors

- Verifies plan hash if `expected_plan_hash` provided; halts immediately on tamper
- Builds command list: team.md commands first, then task-level commands from plan
- Returns `needs_manual_verification` if no commands found
- Builds cache key from repo state + command set; may reuse exact cache hit
- Does not modify project files

---

## final-reviewer

**Role**: Quality  
**Source**: `agents/final-reviewer.md`  
**Tools**: Bash, Read, Glob, Grep  
**May edit project files**: No

### Purpose

Final code review gate. Uses Codex review when available, otherwise Claude-native.

### Inputs

- Review backend: `backend: codex|claude`
- Optional `claude_model`
- Plan file path

### Outputs

- Final review verdict (pass, fail, needs_manual_review)
- Per-criterion pass/fail against acceptance criteria
- Key findings

### Key Behaviors

- Does not implement features or edit files
- Uses plan file as review context (checks implementation matches goals and constraints)
- Validates acceptance criteria per criterion
- Routes to Codex plugin if available; falls back to Claude-native

---

## git-monitor

**Role**: Delivery  
**Source**: `agents/git-monitor.md`  
**Tools**: Bash, Read, Glob, Grep  
**May edit project files**: No (git operations only)

### Purpose

Post-execution lifecycle agent. Stages and commits code changes, creates PRs, monitors CI and PR comments, reports findings to team-lead.

### Inputs

- Plan path
- Modified files list
- Repo root path

### Outputs

- Commit SHA
- PR URL
- CI status
- PR comment summary

### Key Behaviors

- Reads commit/PR format from `.claude/team.md` `## Notes` and `CLAUDE.md`
- Detects current branch and base branch
- Stages only the modified files listed (not `git add .`)
- Creates PR to base branch using `gh pr create`
- Monitors CI workflow runs and PR comments
- Calls `cleanup_pipeline_state()` after successful commit
- Does not push to remote unless explicitly asked

---

## pm

**Role**: Advisory  
**Source**: `agents/pm.md`  
**Tools**: Read, Glob, Grep, Bash  
**May edit project files**: No

### Purpose

Product manager perspective. Validates user value, prioritization, and scope clarity.

### Expertise

- User story validation
- Scope creep detection
- MVP prioritization
- Stakeholder impact analysis
- Acceptance criteria quality

### When Used

Invoked during pre-release flow or adversarial-review mode. Optionally listed in `.claude/team.md` `## Specialty Reviewers`.

---

## security-reviewer

**Role**: Quality  
**Source**: `agents/security-reviewer.md`  
**Tools**: Read, Glob, Grep, Bash  
**May edit project files**: No

### Purpose

Security-focused code reviewer. Identifies vulnerabilities, auth issues, and data exposure risks.

### Expertise

- OWASP Top 10
- Authentication and authorization patterns
- Input validation and sanitization
- Secrets management (hardcoded credentials, env vars, key rotation)
- Dependency vulnerability assessment

### When Used

Pre-release flow security-review node, or adversarial-review mode.

---

## devil-advocate

**Role**: Advisory  
**Source**: `agents/devil-advocate.md`  
**Tools**: Read, Glob, Grep, Bash  
**May edit project files**: No

### Purpose

Adversarial challenger. Stress-tests assumptions, finds edge cases, and proposes simpler alternatives. Improves quality by questioning consensus without obstructing progress.

### Expertise

- Assumption challenging
- Edge case discovery
- Failure mode analysis
- Alternative architecture exploration
- Complexity reduction advocacy

### Model Assignment

Assigned to tier 4 (`claude-haiku-4.5`) — lightweight, frequent invocation in adversarial-review mode.

---

## a11y-reviewer

**Role**: Quality  
**Source**: `agents/a11y-reviewer.md`  
**Tools**: Read, Glob, Grep, Bash  
**May edit project files**: No

### Purpose

Accessibility reviewer. Checks WCAG compliance, screen reader compatibility, and inclusive design patterns.

### Expertise

- WCAG 2.1 AA and AAA success criteria
- ARIA roles, attributes, and states
- Keyboard navigation patterns
- Color contrast requirements (4.5:1 text, 3:1 large text)
- Screen reader testing approaches

### When Used

Pre-release flow or adversarial-review mode.

---

## perf-reviewer

**Role**: Quality  
**Source**: `agents/perf-reviewer.md`  
**Tools**: Read, Glob, Grep, Bash  
**May edit project files**: No

### Purpose

Performance reviewer. Identifies bottlenecks, inefficient algorithms, memory issues, and scalability risks. Focuses on measurable impact, not micro-optimizations.

### Expertise

- Algorithmic complexity analysis (Big O)
- Memory allocation patterns and leaks
- I/O optimization (disk, network, database)
- Caching strategies and invalidation
- Database query performance (N+1, missing indexes, full table scans)

### When Used

Pre-release flow perf-review node.

---

## user-perspective

**Role**: Advisory  
**Source**: `agents/user-perspective.md`  
**Tools**: Read, Glob, Grep, Bash  
**May edit project files**: No

### Purpose

End-user advocate. Evaluates UX quality, error handling clarity, onboarding friction, and user journey coherence by simulating real user interaction.

### Expertise

- UX heuristic evaluation (Nielsen's heuristics)
- Error message quality and recovery guidance
- Onboarding flow assessment
- User journey mapping and coherence
- Edge case discovery from user behavior

### When Used

Advisory role in adversarial-review mode or pre-release flow.
