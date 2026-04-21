---
title: "Enable planner to use superpower skills with team-lead decision"
project: $HOME/Development/planning-team-skill
branch: main
status: draft
created: "2026-04-15"
size: small
tasks:
  - id: T1
    title: "Add Skill tool and superpower invocation section to agents/planner.md"
    size: small
    parallel_group: 1
    executor: copilot
    status: pending
  - id: T2
    title: "Add skill invocation decision logic to agents/team-lead.md"
    size: small
    parallel_group: 1
    executor: copilot
    status: pending
  - id: T3
    title: "Update AGENTS.md planner row to reflect new Skill tool capability"
    size: small
    parallel_group: 2
    executor: copilot
    status: pending
  - id: T4
    title: "Bump version to 0.7.1 in SKILL.md (if version present) and .claude-plugin/plugin.json"
    size: small
    parallel_group: 2
    executor: copilot
    status: pending
acceptance_criteria:
  - "agents/planner.md tools front matter includes Skill"
  - "agents/planner.md has ## Superpower Skills section with invocation guidance"
  - "agents/team-lead.md documents the skill invocation decision criteria for the planner"
  - "AGENTS.md planner row updated to mention Skill tool capability"
  - "Version bumped to 0.7.1 in .claude-plugin/plugin.json"
  - "bash scripts/setup.sh --check passes"
plan_hash: "15bc228fa1518238"
---

## Background

The `planner` agent (`agents/planner.md`) is responsible for creating structured execution plans. Currently it can only use `Read, Write, Glob, Grep, Bash, Agent` tools. There is a rich ecosystem of "superpower skills" installed at `~/.claude/skills/superpowers/` that includes methodologies for writing plans (`writing-plans`), brainstorming design (`brainstorming`), executing plans (`executing-plans`), parallel dispatch (`dispatching-parallel-agents`), TDD (`test-driven-development`), and more.

The user wants the `planner` agent to be able to leverage these skills — invoking them via the `Skill` tool — but wants `team-lead` to be the decision-maker for when skill invocation is appropriate (e.g., based on task complexity, explicit flag, or user request).

## Goals

1. Extend `agents/planner.md` with the `Skill` tool in its hard permission boundary (`tools:` front matter).
2. Add a `## Superpower Skills` section to `agents/planner.md` describing which skills are available, when to invoke them, and how.
3. Add a `## Skill Invocation Decision` section to `agents/team-lead.md` so it can pass `skill_invocation: enabled` with relevant skill names to the planner when appropriate.
4. Update `AGENTS.md` to reflect the updated planner tool list.
5. Bump version as a PATCH (0.7.0 → 0.7.1).

## Research Summary

- `agents/planner.md` — currently `tools: Read, Write, Glob, Grep, Bash, Agent`. Has no Skill tool. Contains Workflow, Required Plan Fields, Review + Approval, Constraints sections.
- `agents/team-lead.md` — has Team, Pipeline Infrastructure, Hard Rules, Governance Model, CLI Backend Detection, Workflow, Gate Policy, Progressive Loading sections. No mention of skill invocation for sub-agents.
- `~/.claude/skills/superpowers/` contains: brainstorming, dispatching-parallel-agents, executing-plans, finishing-a-development-branch, receiving-code-review, requesting-code-review, subagent-driven-development, systematic-debugging, test-driven-development, using-git-worktrees, using-superpowers, verification-before-completion, writing-plans, writing-skills.
- `AGENTS.md` has `planner` row listing `Read, Write, Glob, Grep, Bash, Agent` in the May-Edit column (indirectly via tools).
- `.claude-plugin/plugin.json` version: `0.13.0` (NOTE: this is the plugin version, separate from `VERSION` file which shows `0.7.0`). Must bump plugin.json version.
- `VERSION` file: `0.7.0` — this is the skill bundle version.

## Acceptance Criteria

- `agents/planner.md` tools front matter includes `Skill`
- `agents/planner.md` has `## Superpower Skills` section with invocation guidance covering relevant skills
- `agents/team-lead.md` has decision logic for passing `skill_invocation: enabled` to the planner
- `AGENTS.md` planner row updated
- Version bumped: `VERSION` to `0.7.1`, `.claude-plugin/plugin.json` to `0.13.1`
- `bash scripts/setup.sh --check` passes

## Task Breakdown

### T1: Add Skill tool and superpower invocation section to agents/planner.md

**Files:**
- Modify: `agents/planner.md`

**Steps:**
1. Add `Skill` to the `tools:` front matter line (after `Agent`): `tools: Read, Write, Glob, Grep, Bash, Agent, Skill`
2. Add a new `## Superpower Skills` section before `## Constraints` with:
   - When `skill_invocation: enabled` is passed by team-lead, the planner MUST invoke the `Skill` tool before planning
   - Available skills and when to use each:
     - `superpowers:using-superpowers` — always invoke first if skill_invocation is enabled
     - `superpowers:writing-plans` — invoke when producing a plan in `mode=plan`
     - `superpowers:brainstorming` — invoke when task needs design exploration before planning
     - `superpowers:dispatching-parallel-agents` — invoke when plan has parallel task groups
     - `superpowers:test-driven-development` — invoke when tasks involve writing tests
     - `superpowers:verification-before-completion` — invoke before marking plan complete
   - If `skill_invocation` flag is absent or `disabled`, do not invoke skills (respect team-lead's decision)

**Verification:** Read the modified file and confirm Skill appears in tools and section exists.

### T2: Add skill invocation decision logic to agents/team-lead.md

**Files:**
- Modify: `agents/team-lead.md`

**Steps:**
1. Add a new `## Skill Invocation Decision` section to the Workflow area (after CLI Backend Detection, before the main Workflow numbered list), containing:
   - Decision criteria for enabling skill invocation:
     - Task complexity is `large` or explicitly involves design/architecture decisions → enable
     - User explicitly requests "use superpowers" or "use skills" → always enable
     - Task involves creating plans for multi-phase features → enable
     - Simple single-file patches or docs-only changes → disable (keep planning lean)
   - How to pass the flag: include `skill_invocation: enabled` and `available_skills: [list]` in the planner-lead spawn input
   - Default: disabled (lean planning) unless criteria above met

**Verification:** Read the modified file and confirm section exists.

### T3: Update AGENTS.md planner row

**Files:**
- Modify: `AGENTS.md`

**Steps:**
1. Find the planner row in the Agent Inventory table.
2. Update the Purpose column to note "Can invoke superpower skills when enabled by team-lead".
3. No other rows change.

**Verification:** Read AGENTS.md and confirm planner row updated.

### T4: Bump version

**Files:**
- Modify: `VERSION`
- Modify: `.claude-plugin/plugin.json`

**Steps:**
1. Change `VERSION` from `0.7.0` to `0.7.1`
2. Change `plugin.json` `version` from `0.13.0` to `0.13.1`

**Verification:** `cat VERSION && cat .claude-plugin/plugin.json | grep version`

## Verification Plan

```bash
bash scripts/setup.sh --check
grep "Skill" agents/planner.md
grep "skill_invocation" agents/team-lead.md
grep "Superpower" agents/planner.md
cat VERSION
```

## Layered Dependency Lint Contract

These are agent prompt files only (no code layers). The dependency lint contract from `Types -> Config -> Repo -> Service -> Runtime -> UI` does not apply to documentation/prompt files. No reverse dependencies can be introduced by these changes.

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Skill tool not available in planner's execution environment | Low | Medium | Add fallback note: if Skill tool unavailable, skip gracefully |
| team-lead decision logic too prescriptive | Low | Low | Keep criteria as heuristics, not hard rules |
| Version confusion between VERSION file and plugin.json | Low | Low | Both must be bumped |

