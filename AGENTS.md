# Agents Index

Agent definitions live in `agents/<name>.md`. For repo conventions, style rules, commit guidelines, and versioning policy, see `CLAUDE.md`.

## Agent Inventory

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
| `perf-reviewer` | Quality | No | `agents/perf-reviewer.md` | Performance review; identifies bottlenecks and scalability risks |
| `user-perspective` | Advisory | No | `agents/user-perspective.md` | End-user advocate; evaluates UX quality |

## Validation

Run `bash scripts/setup.sh --check` to verify agent installation status.  
Run `bash scripts/setup.sh --repo` to install/sync agents to `.claude/agents/`.
