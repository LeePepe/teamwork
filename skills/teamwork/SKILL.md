---
name: teamwork
description: Install, check, and maintain the Teamwork Claude pipeline in a repository, including plugin readiness and overload diagnostics.
metadata:
  author: LeePepe
  version: "0.5.0"
---

# Teamwork

Use this skill when the user asks to install, update, verify, or troubleshoot this repository's teamwork setup.

## Scope

This skill manages the Claude-side teamwork package from Codex by running the local setup script and reporting state.

## Resolve Teamwork Root

Always resolve `TEAMWORK_ROOT` before running setup commands (so execution does not depend on current working directory):

```bash
resolve_teamwork_root() {
  if [ -f "scripts/setup.sh" ]; then
    pwd -P
    return 0
  fi

  for base in "$HOME/.agents/skills/teamwork" "$HOME/.claude/skills/teamwork"; do
    [ -d "$base" ] || continue
    skill_dir="$(cd "$base" && pwd -P)"
    for candidate in "$skill_dir/../.." "$skill_dir"; do
      if [ -f "$candidate/scripts/setup.sh" ]; then
        (cd "$candidate" && pwd -P)
        return 0
      fi
    done
  done

  return 1
}

TEAMWORK_ROOT="$(resolve_teamwork_root)" || {
  echo "Unable to locate teamwork root (missing scripts/setup.sh)." >&2
  exit 1
}
```

## Standard workflow

1. Run status check first:

```bash
bash "$TEAMWORK_ROOT/scripts/setup.sh" --check
```

2. If install/update is requested, run one of:

```bash
bash "$TEAMWORK_ROOT/scripts/setup.sh" --repo
bash "$TEAMWORK_ROOT/scripts/setup.sh" --global
```

3. Re-run check and report:
- plugin availability (`codex` / `copilot`)
- whether fallback mode is active
- next command if user still has missing dependencies

## Team-Lead planning from Codex

When the user asks to "start team-lead" or plan fallback/routing behavior:

1. Preflight plugin availability using companion scripts (same logic as `commands/task.md`):

```bash
CODEX_SCRIPT=$(find ~/.claude/plugins -name "codex-companion.mjs" 2>/dev/null | head -1)
COPILOT_SCRIPT=$(find ~/.claude/plugins -name "copilot-companion.mjs" 2>/dev/null | head -1)
echo "codex=$([ -n "$CODEX_SCRIPT" ] && echo true || echo false) copilot=$([ -n "$COPILOT_SCRIPT" ] && echo true || echo false)"
```

2. Ensure `team-lead` is present using the loader snippet in `commands/task.md` (Step 2.5).
3. Derive executor constraint and planning path:
- both true -> route by plan task annotation (`executor: codex|copilot`)
- codex=true, copilot=false -> force `codex-coder`
- codex=false, copilot=true -> force `copilot`
- both false -> force `claude-coder` and choose `haiku|sonnet|opus` by complexity
4. Enforce runtime guardrails before implementation:
- keep active delegated agents bounded; close completed agents before spawning new ones
- if `spawn_agent` fails due thread limit/resource errors, close stale agents and retry once
- track automatic repair count and stop at one repair cycle
- after any code-changing repair, re-run verifier/final-review on fresh evidence
5. Return a concrete execution plan before implementation, including:
- expected copilot usage (`invoked true|false` conditions)
- final reporting fields (copilot evidence + boundary violations)

## Overload diagnostics

If user reports `529 overloaded_error` after setup:

1. Re-run `bash "$TEAMWORK_ROOT/scripts/setup.sh" --check`
2. Detect recursive cache paths:

```bash
find ~/.claude/plugins/cache/teamwork -type d -path "*/teamwork/*/teamwork/*" | head
```

3. If recursion exists, clean cache and ask user to reload plugins:

```bash
rm -rf ~/.claude/plugins/cache/teamwork
```

Then tell user to run `/reload-plugins` in Claude Code.
