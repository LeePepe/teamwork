---
description: Install teamwork agents and skill file into your repo or global ~/.claude/. Pass --global for a global install or --check to inspect current status (including researcher/claude-coder/verifier/final-reviewer agents).
argument-hint: "[--global|--repo|--check]"
allowed-tools: Bash
---

Validate the argument before running the setup script.

Accepted values for `${ARGUMENTS}` are exactly: `--global`, `--repo`, `--check`, or empty (default `--repo`).

If the argument is anything other than those three values (or empty), stop immediately and tell the user:
> Invalid argument. Accepted values are: --global, --repo, --check (or leave blank for the default --repo).

If the argument is valid (or empty), run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" ${ARGUMENTS:---repo}
```

Report the output clearly, including any missing plugins and the commands needed to install them.
