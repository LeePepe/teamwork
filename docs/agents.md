# Agents

This document describes the active agent topology after the plan-lead governance refactor.

## Core Orchestration

### team-lead

**Source**: `agents/team-lead.md`  
**Role**: Pipeline orchestrator (no file edits)

Owns stage transitions, gate policy, repair budget, and final summary.

### plan-lead

**Source**: `agents/plan-lead.md`  
**Role**: Unified planning owner

Combines research orchestration and planning into one role:
- dispatches `researcher`
- dispatches `designer` when required
- dispatches `linter` for strict architecture lint contracts
- produces the plan directly

### linter

**Source**: `agents/linter.md`  
**Role**: Architecture lint specialist

Defines deterministic lint policy for strict layered dependency enforcement:
- layer order: `Types -> Config -> Repo -> Service -> Runtime -> UI`
- lower layers cannot reverse-depend on upper layers
- lint diagnostics must explain why the rule exists and how to fix violations
- violations are CI-blocking regardless of human/AI code authorship

## Planning and Governance Gates

### plan-reviewer

**Source**: `agents/plan-reviewer.md`  
**Role**: Technical plan gate

Reviews feasibility, dependency ordering, verification completeness, and execution safety.

### pm

**Source**: `agents/pm.md`  
**Role**: Product gate and delivery supervisor

- `mode: plan-gate`: co-approves plan with `plan-reviewer`
- `mode: delivery-gate`: supervises task outcomes and testing evidence quality

## Execution and Verification

### fullstack-engineer

**Source**: `agents/fullstack-engineer.md`  
**Role**: Implementation executor

Uses backend priority: Copilot -> Claude-native -> Codex (tertiary fallback).

### verifier

**Source**: `agents/verifier.md`  
**Role**: Command-level verification gate

Runs verification commands and returns concrete evidence.

## Final Review Coalition

### final-reviewer

**Source**: `agents/final-reviewer.md`  
**Role**: Coalition lead + final code reviewer

Runs code review and orchestrates specialty reviewers:
- `security-reviewer`
- `devil-advocate`
- `a11y-reviewer`
- `perf-reviewer`
- `user-perspective`

### Specialty reviewers

- `agents/security-reviewer.md`
- `agents/devil-advocate.md`
- `agents/a11y-reviewer.md`
- `agents/perf-reviewer.md`
- `agents/user-perspective.md`

## Delivery

### git-monitor

**Source**: `agents/git-monitor.md`  
**Role**: Commit/PR/CI lifecycle

Runs after final gate pass when code changed.

## Legacy Roles

`research-lead` and `planner` remain in `agents/` for compatibility/history but are superseded by `plan-lead` in the active pipeline.
