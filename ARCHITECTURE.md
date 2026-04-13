# Architecture

This repository is a Claude Code skill (`SKILL.md`) plus agent definitions (`agents/`) that implement a structured multi-agent pipeline: research → plan → review → design (optional) → execute → verify → final-review → ship. The artifacts are Markdown prompt files installed to `~/.claude/` or `.claude/`.

## Pipeline Diagram

```
/teamwork:task <description>
        │
        ▼
  [SKILL.md entry]  validate plugins, read team config
        │
        ▼
  team-lead  ── orchestrates only, never modifies files
        │
        ├─ Guide A: research stage ──────────────────────────────────┐
        │   research-lead  ← splits scopes, selects backends          │
        │     └── researcher(s)  [parallel when independent]         │
        │           code scopes  → codex backend                     │
        │           web scopes   → copilot (Claude path)             │
        │     optional: planner (mode: probe) → gap detection        │
        │   consolidates brief → research_status: ok|partial|unavail │
        │                                                             │
        ├─ Guide B: plan stage ───────────────────────────────────────┤
        │   planner          ← writes .claude/plan/<slug>.md         │
        │   plan-reviewer    ← gates quality; review|adversarial     │
        │                                                             │
        ├─ Guide C: design stage (conditional) ──────────────────────┤
        │   designer         ← produces design plan + handoff        │
        │                       skipped unless design explicitly req  │
        │                                                             │
        ├─ Guide D: execution stage ─────────────────────────────────┤
        │   fullstack-engineer  [parallel tasks where possible]       │
        │     tries: codex-companion.mjs → copilot-companion.mjs     │
        │     falls back to: Claude-native                            │
        │   verifier         ← runs post-execution checks            │
        │   final-reviewer   ← final review gate                     │
        │   git-monitor      ← (optional) commit, PR, CI watch       │
        │                                                             │
        └─ Specialty reviewers (pre-release flow only) ──────────────┘
            security-reviewer, perf-reviewer, a11y-reviewer,
            devil-advocate, pm, user-perspective
```

ASCII flow state rendering (produced after each stage):
```
[✅ research] → [✅ plan] → [▶ plan-review] → [○ execute] → [○ verify] → [○ final-review] → [○ ship]
```

## Component Map

| Component | Type | Location | Purpose |
|-----------|------|----------|---------|
| SKILL.md | Skill entry | `SKILL.md` / `.claude/skills/teamwork/SKILL.md` | Plugin validation, team config read, team-lead delegation |
| team-lead | Agent | `agents/team-lead.md` | Pipeline orchestrator; never writes project files |
| research-lead | Agent | `agents/research-lead.md` | Research scope split, backend routing, brief consolidation |
| researcher | Agent | `agents/researcher.md` | Single-scope code/web research worker |
| planner | Agent | `agents/planner.md` | Creates `.claude/plan/<slug>.md` from research brief |
| plan-reviewer | Agent | `agents/plan-reviewer.md` | Reviews and gates plan quality |
| designer | Agent | `agents/designer.md` | Design plans for design-heavy tasks |
| fullstack-engineer | Agent | `agents/fullstack-engineer.md` | Unified executor (Codex → Copilot → Claude-native) |
| verifier | Agent | `agents/verifier.md` | Post-execution verification gate |
| final-reviewer | Agent | `agents/final-reviewer.md` | Final code review gate |
| git-monitor | Agent | `agents/git-monitor.md` | Commit, PR creation, CI monitoring |
| Specialty reviewers | Agents | `agents/{pm,security-reviewer,...}.md` | Advisory and quality roles |
| pipeline-lib.sh | Shell library | `scripts/pipeline-lib.sh` | Tamper protection, state management, flow engine |
| setup.sh | Script | `scripts/setup.sh` | Install/check skill and agents |
| Flow templates | YAML | `templates/flow-*.yaml` | Named pipeline graphs (standard, review, build-verify, pre-release) |
| team.md template | Config template | `templates/team.md` | Copied to `.claude/team.md` on first `--repo` install |
| Commands | Slash commands | `commands/*.md` | `/teamwork:task`, `/teamwork:setup`, etc. |
| Pipeline state | Ephemeral JSON | `.claude/pipeline-state.json` | Cross-session resume; never committed |

## Agent Responsibilities

| Agent | Role | May Edit Files? | Source Path | Purpose |
|-------|------|----------------|-------------|---------|
| `team-lead` | Orchestration | No | `agents/team-lead.md` | Pipeline orchestrator; delegates to all other agents |
| `research-lead` | Research | No | `agents/research-lead.md` | Splits scopes, routes backends, dispatches/merges researchers |
| `researcher` | Research | No | `agents/researcher.md` | Single-scope code/web research worker |
| `planner` | Planning | Plan files only | `agents/planner.md` | Creates structured plan files from research briefs |
| `plan-reviewer` | Planning | Plan files only | `agents/plan-reviewer.md` | Reviews and gates plan quality |
| `designer` | Design | Plan/design files only | `agents/designer.md` | Produces design plans for design-heavy tasks before execution |
| `fullstack-engineer` | Execution | Yes | `agents/fullstack-engineer.md` | Unified executor — Codex → Copilot → Claude-native fallback |
| `verifier` | Quality | No | `agents/verifier.md` | Runs post-execution verification commands |
| `final-reviewer` | Quality | No | `agents/final-reviewer.md` | Final code review gate |
| `git-monitor` | Delivery | No | `agents/git-monitor.md` | Stages commits, creates PRs, monitors CI |
| `pm` | Advisory | No | `agents/pm.md` | Product manager perspective; validates user value and scope |
| `security-reviewer` | Quality | No | `agents/security-reviewer.md` | Security-focused code review; identifies vulnerabilities |
| `devil-advocate` | Advisory | No | `agents/devil-advocate.md` | Adversarial challenger; stress-tests assumptions |
| `a11y-reviewer` | Quality | No | `agents/a11y-reviewer.md` | Accessibility review; WCAG compliance checks |
| `perf-reviewer` | Quality | No | `agents/perf-reviewer.md` | Performance review; identifies bottlenecks |
| `user-perspective` | Advisory | No | `agents/user-perspective.md` | End-user advocate; evaluates UX quality |

## Key Design Decisions

### Hard Pipeline Rule: No Direct File Mutation from Orchestrators

`team-lead`, `research-lead`, `planner`, `plan-reviewer`, `designer`, `verifier`, `final-reviewer`, `git-monitor`, and all specialty reviewers have write access restricted to their own artifacts (plan files, review output). Only `fullstack-engineer` may modify project source files. This prevents accidental corruption by orchestration agents.

### Tamper Protection

Pipeline integrity is enforced through shell-level mechanisms in `pipeline-lib.sh`, not prompt-level honor systems:

- **Plan hash**: SHA256 truncated to 16 hex chars, computed at plan creation, verified before each execution step. Hash mismatch halts the pipeline with `tamper_detected`.
- **Write nonce**: 16-hex random nonce generated at pipeline start, stored in `pipeline-state.json`. All state transitions verify the nonce.
- **Repair budget**: `enforce_repair_budget()` is called before any repair action. If `repair_count >= 1`, the pipeline halts with `repair_budget_exhausted`.
- **Oscillation detection**: Tracks last 6 stage transitions. If an A→B→A→B pattern is detected (4+ alternations), the pipeline warns and offers escape hatches.
- **Review independence**: In adversarial-review mode, reviewer outputs are compared for >95% similarity. If too similar, a re-review from a different perspective is requested.

### Flow Engine

The pipeline uses directed graph templates (`templates/flow-*.yaml`) with typed nodes (`discussion`, `build`, `review`, `execute`, `gate`) and conditional edges. Gate verdicts (🔴 FAIL, 🟡 ITERATE, 🟢 PASS) are computed mechanically by `get_gate_verdict()` from reviewer output markers. Cycle limits (`max_pipeline_steps`, `max_review_loops`, per-edge `max_cycles`) prevent runaway loops.

### Progressive (Lazy) Agent Loading

Agents are loaded only when their pipeline stage is entered, not at startup. The default install (`--repo` without `--full-agents`) preloads only `team-lead` into `.claude/agents/`; all other agents live in `.claude/skills/teamwork/agents/` and are copied on demand. This keeps baseline context small and reduces 529 overload risk.

### Plugin Fallback Policy

The executor (`fullstack-engineer`) tries backends in order: Codex plugin → Copilot plugin → Claude-native. Research backend routing follows model focus policy when both plugins are available:
- Code investigation scopes → Codex (stability/accuracy)
- Web/external research scopes → Copilot Claude path (open-ended synthesis)
- Mixed scopes split into separate code/web scopes before dispatch

### Model Tier Routing

Agents are assigned to four autonomy tiers (`templates/model-tiers.md`). Per-repo model overrides are configured in `.claude/team.md` `## Model Config` with Primary and Secondary provider maps. Resolution order: Primary role → Secondary role → Primary default → Secondary default → omit.

### State Persistence

Pipeline state lives in `.claude/pipeline-state.json` (ephemeral, never committed). On pipeline start, `resume_pipeline()` detects existing state and offers resume/restart. State is cleaned up after `git-monitor` successfully commits.

## File Layout

```
planning-team-skill/
├── SKILL.md                        ← skill entry point (validates plugins, delegates to team-lead)
├── ARCHITECTURE.md                 ← this file
├── AGENTS.md                       ← agent inventory table (TOC)
├── CLAUDE.md                       ← project conventions for Claude Code
├── README.md                       ← user-facing documentation
├── VERSION                         ← version string (MAJOR.MINOR.PATCH)
│
├── agents/                         ← canonical source agent files
│   ├── team-lead.md
│   ├── research-lead.md
│   ├── researcher.md
│   ├── planner.md
│   ├── plan-reviewer.md
│   ├── designer.md
│   ├── fullstack-engineer.md
│   ├── verifier.md
│   ├── final-reviewer.md
│   ├── git-monitor.md
│   ├── pm.md
│   ├── security-reviewer.md
│   ├── devil-advocate.md
│   ├── a11y-reviewer.md
│   ├── perf-reviewer.md
│   ├── user-perspective.md
│   └── openai.yaml                 ← Codex plugin display metadata
│
├── commands/                       ← slash command handlers
│   ├── task.md                     ← /teamwork:task
│   ├── setup.md                    ← /teamwork:setup
│   ├── mapping-repo.md             ← /teamwork:mapping-repo
│   ├── flow.md                     ← /teamwork:flow
│   ├── skip.md                     ← /teamwork:skip
│   ├── pass.md                     ← /teamwork:pass
│   ├── stop.md                     ← /teamwork:stop
│   └── goto.md                     ← /teamwork:goto
│
├── scripts/
│   ├── setup.sh                    ← install/check script (set -euo pipefail)
│   └── pipeline-lib.sh             ← shared shell functions (tamper protection, state, flow)
│
├── templates/
│   ├── team.md                     ← .claude/team.md template for new repos
│   ├── model-tiers.md              ← agent-to-tier assignments and provider model map
│   ├── flow-standard.yaml          ← full pipeline flow graph
│   ├── flow-review.yaml            ← review-only flow
│   ├── flow-build-verify.yaml      ← quick build-and-verify flow
│   └── flow-pre-release.yaml       ← extended pipeline with security/perf gates
│
├── test/
│   └── test-pipeline.sh            ← pipeline-lib.sh unit tests
│
├── docs/                           ← topic reference documentation
│   ├── pipeline.md
│   ├── agents.md
│   ├── commands.md
│   ├── configuration.md
│   ├── installation.md
│   └── extending.md
│
├── skills/                         ← Codex skill discovery path
│   └── teamwork/
│       └── SKILL.md                ← symlink/copy for Codex native skill discovery
│
└── .claude/                        ← repo-local runtime files (not all committed)
    ├── team.md                     ← per-repo config (executor routing, model config, etc.)
    ├── agents/                     ← installed agent copies (team-lead.md always present)
    ├── skills/teamwork/            ← installed skill bundle
    │   ├── SKILL.md
    │   ├── agents/                 ← lazy-load source for all runtime agents
    │   ├── scripts/pipeline-lib.sh
    │   └── templates/flow-*.yaml
    └── plan/                       ← plan files written by planner
        └── <slug>.md
```
