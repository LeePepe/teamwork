# Repository Guidelines

## Layout
- `SKILL.md`: teamwork skill contract and pipeline behavior.
- `agents/*.md`: role prompts (`team-lead`, `research-lead`, `researcher`, `planner`, `plan-reviewer`, executors, gates).
- `commands/task.md`: runtime orchestration entry.
- `scripts/setup.sh`: install/check for `~/.claude` and repo `.claude`.
- `templates/team.md`: repo routing/review/verification defaults.
- `README.md`: install/usage/troubleshooting docs.

## Navigation
- Orchestration: `agents/team-lead.md`
- Research split/merge: `agents/research-lead.md`
- Code/web research worker: `agents/researcher.md`
- Plan generation/probe: `agents/planner.md`
- Verification cache gate: `agents/verifier.md`

## Validation Commands
- `bash scripts/setup.sh --check`
- `bash scripts/setup.sh --repo`
- `bash scripts/setup.sh --global`
- `bash -n scripts/setup.sh`

Run `--check` before and after setup-related changes.

## Style
- Bash: keep `set -euo pipefail`, use small functions, quote expansions.
- Prompt files: YAML front matter first (`name`, `description`, optional `tools`).
- Naming: lowercase kebab-case for agent/doc filenames.
- Keep examples copy-paste ready and path-specific.

## Context Hygiene
- Keep prompts compact and scope-local.
- Avoid whole-repo summaries in researcher/planner flows.
- Prefer path/symbol references over long pasted code blocks.

## Testing
Operational smoke test:
1. `bash scripts/setup.sh --check`
2. run install flow (`--repo` or `--global`)
3. `bash scripts/setup.sh --check` again
4. verify expected files under target `.claude` paths

For setup script changes, verify idempotency (running install twice stays valid).

## Commit/Push Rule
Every time code is modified in this repo, finish both steps in the same task:
1. Create a commit (Conventional Commits style).
2. Push to `origin/<current-branch>` unless user explicitly says not to push.

## PR Notes
Include:
1. what changed and why
2. validation commands and key outputs
3. related docs/template updates
4. linked issue/context (if any)

## Security
- Never commit secrets or machine-specific credentials.
- If touching `~/.claude/settings.json` behavior, preserve existing user settings and append-only required marketplace entries.
