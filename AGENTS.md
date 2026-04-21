# Agents Index

Agent definitions live in `agents/<name>.md`. For repo conventions, style rules, commit guidelines, and versioning policy, see `CLAUDE.md`.

## Agent Inventory

| Agent | Role | May Edit Files? | Source Path | Purpose |
|-------|------|----------------|-------------|---------|
| `team-lead` | Orchestration | No | `agents/team-lead.md` | Pipeline orchestrator; delegates to all other agents |
| `planner-lead` | Planning | Plan/design files only | `agents/planner-lead.md` | Unified planning lead: orchestrates researcher/designer/linter and writes plan; can invoke superpower skills |
| `linter` | Planning | No | `agents/linter.md` | Defines strict layered-dependency lint contract and CI blocking policy |
| `researcher` | Research | No | `agents/researcher.md` | Single-scope code/web research worker |
| `plan-reviewer` | Planning | Plan files only | `agents/plan-reviewer.md` | Reviews and gates plan quality |
| `designer` | Design | Plan/design files only | `agents/designer.md` | Design specialist dispatched by `planner-lead` when required |
| `fullstack-engineer` | Execution | Yes | `agents/fullstack-engineer.md` | Unified executor — Codex → Copilot → Claude-native fallback |
| `verifier` | Quality | No | `agents/verifier.md` | Runs post-execution verification commands |
| `final-reviewer` | Quality | No | `agents/final-reviewer.md` | Leads specialty review coalition and performs final code review |
| `git-monitor` | Delivery | No | `agents/git-monitor.md` | Stages commits, creates PRs, monitors CI |
| `pm` | Quality | No | `agents/pm.md` | Co-approves plan with plan-reviewer; supervises task outcomes and tests |
| `security-reviewer` | Quality | No | `agents/security-reviewer.md` | Security-focused code review; identifies vulnerabilities |
| `devil-advocate` | Advisory | No | `agents/devil-advocate.md` | Adversarial challenger; stress-tests assumptions |
| `a11y-reviewer` | Quality | No | `agents/a11y-reviewer.md` | Accessibility review; WCAG compliance checks |
| `perf-reviewer` | Quality | No | `agents/perf-reviewer.md` | Performance review; identifies bottlenecks and scalability risks |
| `user-perspective` | Advisory | No | `agents/user-perspective.md` | End-user advocate; evaluates UX quality |
| `docs-auditor` | Quality | No | `agents/docs-auditor.md` | Documentation-code drift auditor; scans for inconsistencies |

## Validation

Claude Code: run `/teamwork:setup --check` to verify plugin and marketplace status.  
CLI/Codex fallback: run `bash scripts/setup.sh --check`.

Claude Code: run `/teamwork:setup` to install into the current repo (creates `.claude/team.md` if missing).  
CLI/Codex fallback: run `bash scripts/setup.sh --repo`.

Before push/PR actions, ensure GitHub CLI is using the `LeePepe` account:  
`gh auth status`  
If the active account is not `LeePepe`, switch first:  
`gh auth switch --user LeePepe`

## Completion Rule

When work is completed:
- Automatically bump version according to policy in `CLAUDE.md` / `docs/extending.md`.
- Automatically commit the changes.
- Automatically push to the current remote branch.
