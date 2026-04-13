---
name: teamwork
description: Install, check, and maintain the Teamwork Claude pipeline in a repository.
metadata:
  author: LeePepe
  version: "0.6.2"
---

# Teamwork

Use this skill for setup/check/maintenance of this teamwork repository from Codex.

## Resolve Teamwork Root

Always resolve `TEAMWORK_ROOT` before any setup command:

```bash
resolve_teamwork_root() {
  if [ -n "${TEAMWORK_ROOT:-}" ] && [ -f "$TEAMWORK_ROOT/scripts/setup.sh" ]; then
    (cd "$TEAMWORK_ROOT" && pwd -P)
    return 0
  fi

  if [ -f "scripts/setup.sh" ]; then
    pwd -P
    return 0
  fi

  for base in "$HOME/.agents/skills/teamwork" "$HOME/.claude/skills/teamwork"; do
    [ -e "$base" ] || continue
    skill_dir="$(cd "$base" && pwd -P)"

    repo_root=""
    case "$skill_dir" in
      */skills/teamwork)
        repo_root="${skill_dir%/skills/teamwork}"
        ;;
      */skills)
        repo_root="${skill_dir%/skills}"
        ;;
    esac

    for candidate in "$repo_root" "$skill_dir"; do
      [ -n "$candidate" ] || continue
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

## Standard Workflow

1. Run check first:

```bash
bash "$TEAMWORK_ROOT/scripts/setup.sh" --check
```

2. If install/update is requested:

```bash
bash "$TEAMWORK_ROOT/scripts/setup.sh" --repo
bash "$TEAMWORK_ROOT/scripts/setup.sh" --global
```

3. Re-run check and report:
- plugin availability (`codex` / `copilot`)
- fallback mode status
- next command if dependency is missing

## Team-Lead Planning from Codex

When user asks to start team-lead or decide fallback/routing:

1. Preflight plugin availability:

```bash
CODEX_SCRIPT=$(find ~/.claude/plugins -name "codex-companion.mjs" 2>/dev/null | head -1)
COPILOT_SCRIPT=$(find ~/.claude/plugins -name "copilot-companion.mjs" 2>/dev/null | head -1)
echo "codex=$([ -n "$CODEX_SCRIPT" ] && echo true || echo false) copilot=$([ -n "$COPILOT_SCRIPT" ] && echo true || echo false)"
```

2. Ensure `team-lead` is present (use `commands/task.md` Step 2.5 snippet).
3. Derive executor constraint:
- both true -> use plan annotations (`codex|copilot`)
- codex=true copilot=false -> force `codex-coder`
- codex=false copilot=true -> force `copilot`
- both false -> force `claude-coder` and choose `haiku|sonnet|opus`
4. Enforce guardrails:
- bound active delegated agents
- retry spawn once after closing stale agents
- one automatic repair cycle max
- re-run verifier/final-review after any code-changing repair
5. Enforce design-first for design-heavy tasks:
- call `designer` first
- require `design_plan_path` before execution
6. Return execution plan with:
- expected copilot usage
- final reporting fields (copilot evidence + boundary violations)

## Overload Diagnostics

If user reports `529 overloaded_error`:

1. Re-run check:

```bash
bash "$TEAMWORK_ROOT/scripts/setup.sh" --check
```

2. Detect recursive cache:

```bash
find ~/.claude/plugins/cache/teamwork -type d -path "*/teamwork/*/teamwork/*" | head
```

3. If recursion exists:

```bash
rm -rf ~/.claude/plugins/cache/teamwork
```

Then ask user to run `/reload-plugins` in Claude Code.
