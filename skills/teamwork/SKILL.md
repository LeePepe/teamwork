---
name: teamwork
description: Install, check, and maintain the Teamwork Claude pipeline in a repository, including plugin readiness and overload diagnostics.
metadata:
  author: LeePepe
  version: "0.1.0"
---

# Teamwork

Use this skill when the user asks to install, update, verify, or troubleshoot this repository's teamwork setup.

## Scope

This skill manages the Claude-side teamwork package from Codex by running the local setup script and reporting state.

## Standard workflow

1. Run status check first:

```bash
bash scripts/setup.sh --check
```

2. If install/update is requested, run one of:

```bash
bash scripts/setup.sh --repo
bash scripts/setup.sh --global
```

3. Re-run check and report:
- plugin availability (`codex` / `copilot`)
- whether fallback mode is active
- next command if user still has missing dependencies

## Overload diagnostics

If user reports `529 overloaded_error` after setup:

1. Re-run `bash scripts/setup.sh --check`
2. Detect recursive cache paths:

```bash
find ~/.claude/plugins/cache/teamwork -type d -path "*/teamwork/*/teamwork/*" | head
```

3. If recursion exists, clean cache and ask user to reload plugins:

```bash
rm -rf ~/.claude/plugins/cache/teamwork
```

Then tell user to run `/reload-plugins` in Claude Code.
