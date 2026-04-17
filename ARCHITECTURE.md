# Architecture

## High-Level Pipeline

```
team-lead
  -> planner-lead (dispatches researcher/designer/linter, outputs plan)
  -> plan gate: plan-reviewer + pm (both must pass)
  -> fullstack-engineer (execution)
  -> verifier (test/command evidence)
  -> pm delivery gate (outcome + test adequacy supervision)
  -> final-reviewer (code review + specialty coalition)
  -> git-monitor (optional ship automation)
```

Default flow template (`standard`):

`plan -> plan-review -> execute -> verify -> pm-review -> final-review -> ship`

## Role Entry by Stage

| Stage | Entering Roles |
|-------|----------------|
| Plan | `planner-lead` (internally: `researcher`, optional `designer`) |
| Plan Lint Contract | `linter` (dispatched by `planner-lead`) |
| Plan Gate | `plan-reviewer`, `pm` |
| Execute | `fullstack-engineer` |
| Verify | `verifier` |
| PM Delivery Gate | `pm` |
| Final Review | `final-reviewer` (internally: `security-reviewer`, `devil-advocate`, `a11y-reviewer`, `perf-reviewer`, `user-perspective`) |
| Ship | `git-monitor` |

## Components

| Component | Type | Path | Purpose |
|-----------|------|------|---------|
| Skill entry | Skill | `SKILL.md` | Activates teamwork and delegates to `team-lead` |
| Team orchestrator | Agent | `agents/team-lead.md` | Stage orchestration and gate control |
| Unified planning | Agent | `agents/planner-lead.md` | Research/design coordination + plan generation |
| Planning lint specialist | Agent | `agents/linter.md` | Encodes strict layer dependency rules and lint diagnostics |
| Technical plan gate | Agent | `agents/plan-reviewer.md` | Feasibility/dependency/risk review |
| Product gate | Agent | `agents/pm.md` | Plan co-approval + delivery supervision |
| Execution | Agent | `agents/fullstack-engineer.md` | Implements planned tasks |
| Verification | Agent | `agents/verifier.md` | Runs verification commands and reports evidence |
| Final coalition lead | Agent | `agents/final-reviewer.md` | Code review + specialty reviewer aggregation |
| Shipping | Agent | `agents/git-monitor.md` | Commit/PR/CI follow-up |
| Flow templates | YAML | `templates/flow-*.yaml` | Flow graphs and cycle limits |
| Pipeline library | Shell | `scripts/pipeline-lib.sh` | Hash/nonce/state/flow helpers |
| Setup | Shell | `scripts/setup.sh` | Setup/check for slash + CLI workflows |

## Integrity and Control

- Plan hash checked before execution and gates.
- Lint is mandatory in verification and CI merge gate.
- Canonical layer model: `Types -> Config -> Repo -> Service -> Runtime -> UI` with no reverse dependencies.
- Nonce required for state transitions.
- Repair budget enforced to prevent endless loops.
- Oscillation detection warns on loop patterns.
- Pipeline state stored in `.claude/pipeline-state.json` (ephemeral, never commit).

## Repo Layout

```
planning-team-skill/
├── agents/
│   ├── team-lead.md
│   ├── planner-lead.md
│   ├── plan-reviewer.md
│   ├── pm.md
│   ├── fullstack-engineer.md
│   ├── verifier.md
│   ├── final-reviewer.md
│   ├── git-monitor.md
│   ├── researcher.md
│   ├── designer.md
│   └── specialty reviewers...
├── commands/
├── templates/
│   ├── flow-standard.yaml
│   ├── flow-build-verify.yaml
│   ├── flow-pre-release.yaml
│   └── flow-review.yaml
├── scripts/
│   ├── setup.sh
│   └── pipeline-lib.sh
├── docs/
└── SKILL.md
```
