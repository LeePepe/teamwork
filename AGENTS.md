# Repository Guidelines

## Project Structure & Module Organization
This repository ships a Claude Code skill plus agent definitions.

- `SKILL.md`: core teamwork skill behavior and workflow.
- `.codex-plugin/plugin.json`: Codex plugin metadata for this repo.
- `skills/teamwork/SKILL.md`: Codex skill entry for setup/check/troubleshooting flows.
- `agents/`: role-specific agent prompts (`team-lead.md`, `researcher.md`, `planner.md`, `plan-reviewer.md`, `codex-coder.md`, `copilot.md`, `claude-coder.md`, `verifier.md`, `final-reviewer.md`, `git-monitor.md`).
- `scripts/setup.sh`: installer/checker for global (`~/.claude`) or repo-local (`.claude`) setup.
- `templates/team.md`: template for per-repo routing, review, and verification preferences.
- `README.md`: usage, installation, and dependency docs.

Keep new role prompts in `agents/` and reusable config defaults in `templates/`.

## Basic Navigation Map

- `SKILL.md`: skill entry, stage orchestration contract.
- `.codex-plugin/plugin.json`: Codex plugin manifest.
- `skills/teamwork/SKILL.md`: Codex discoverable skill payload.
- `commands/task.md`: runtime task entry; passes routing/research/verification policy into `team-lead`.
- `commands/setup.md`: user-facing setup command contract.
- `agents/team-lead.md`: stage-by-stage loading guides and orchestration policy.
- `agents/researcher.md`: code read/search owner; scoped area map outputs.
- `agents/planner.md`: converts research maps into minimal-scope execution plans.
- `agents/verifier.md`: verification gate with cache-aware behavior.
- `scripts/setup.sh`: install/check behavior for global/repo skill layout.

## Build, Test, and Development Commands
There is no compile/build step; validation is script-driven.

- `bash scripts/setup.sh --check`: verify plugin, agent, and skill installation status.
- `bash scripts/setup.sh --global`: install to `~/.claude/agents` and `~/.claude/skills/teamwork`.
- `bash scripts/setup.sh --repo`: install to current repo’s `.claude/` directory.
- `bash -n scripts/setup.sh`: quick shell syntax check before committing script changes.

Use `--check` before and after modifying setup behavior.

## Coding Style & Naming Conventions
- Bash: keep `set -euo pipefail`, prefer small helper functions, and quote variable expansions.
- Markdown prompts/skills: YAML front matter first (`name`, `description`, optional `tools`), then clear sectioned instructions.
- File naming: lowercase kebab-case for agents and docs (example: `plan-reviewer.md`).
- Keep command examples copy-paste ready and path-specific.

## Testing Guidelines
No formal test framework is configured yet. Treat validation as operational smoke tests:

1. Run `bash scripts/setup.sh --check`.
2. Run install flow (`--global` or `--repo`), then run `--check` again.
3. Confirm expected files exist in target `.claude` directories.

When changing setup logic, verify idempotency (running install twice should not break state).

## Commit & Pull Request Guidelines
Git history uses Conventional Commits (`feat: ...`). Continue with `type: short imperative summary` (e.g., `fix: handle missing repo root in --repo mode`).

Every time code is modified, complete the cycle in the same task:
1. Create a commit.
2. Push to remote (`origin/<current-branch>`), unless the user explicitly asks not to push.

For PRs, include:

1. What changed and why.
2. Commands run for validation (with key output).
3. Any docs/template updates required by behavior changes.
4. Linked issue/context when applicable.

## Security & Configuration Notes
- Do not commit secrets or machine-specific credentials.
- Changes touching `~/.claude/settings.json` behavior must preserve existing user settings and only append required marketplace entries.
