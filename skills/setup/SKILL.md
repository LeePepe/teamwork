---
name: setup
description: Install planning-team-skill agents and skill file. Run after installing the plugin. Pass --global (default) or --repo to select install scope, or --check to inspect status.
argument-hint: "[--global|--repo|--check]"
allowed-tools: Bash
---

Run the setup script to install agents and the planning-team skill:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" ${ARGUMENTS:---global}
```

Report the output clearly, including any missing plugins and the commands needed to install them.
