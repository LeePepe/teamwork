#!/usr/bin/env bash
# setup.sh — Install/check teamwork configuration for Claude and Codex workflows.
#
# Usage:
#   bash scripts/setup.sh [--global] [--repo] [--check] [--full-agents]
#
# Flags:
#   --global       Configure ~/.claude (no repo required)
#   --repo         Configure current git repo (default)
#   --check        Status only (no writes)
#   --full-agents  Preload all agents into .claude/agents (legacy eager mode)

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$SCRIPT_ROOT}"
SETTINGS="$HOME/.claude/settings.json"
TEAMWORK_CACHE_ROOT="$HOME/.claude/plugins/cache/teamwork"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "  $*"; }

MODE="repo"
CHECK_ONLY=false
FULL_AGENTS=false
for arg in "$@"; do
  case "$arg" in
    --global) MODE="global" ;;
    --repo) MODE="repo" ;;
    --check) CHECK_ONLY=true ;;
    --full-agents) FULL_AGENTS=true ;;
    *)
      fail "Unknown argument: $arg"
      info "Accepted values: --global, --repo, --check, --full-agents"
      exit 1
      ;;
  esac
done

CODEX_OK=false
COPILOT_OK=false
[ -n "$(which codex 2>/dev/null)" ]   && CODEX_OK=true   || true
[ -n "$(which copilot 2>/dev/null)" ] && COPILOT_OK=true || true

has_recursive_cache() {
  [ -d "$TEAMWORK_CACHE_ROOT" ] || return 1
  local hit
  hit=$(find "$TEAMWORK_CACHE_ROOT" -type d -path "*/teamwork/*/teamwork/*" -print -quit 2>/dev/null || true)
  [ -n "$hit" ]
}

is_from_cache() {
  case "$PLUGIN_ROOT" in
    "$TEAMWORK_CACHE_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ "$MODE" = "repo" ] && [ -z "$REPO_ROOT" ] && ! $CHECK_ONLY; then
  fail "--repo requires a git repository. Use --global outside a repo."
  exit 1
fi

AGENTS_DIR="$HOME/.claude/agents"
if [ "$MODE" = "repo" ] && [ -n "$REPO_ROOT" ]; then
  AGENTS_DIR="$REPO_ROOT/.claude/agents"
fi
TEAM_MD="${REPO_ROOT}/.claude/team.md"
TEAM_TEMPLATE="$PLUGIN_ROOT/templates/team.md"
AGENTS_SOURCE_DIR="$PLUGIN_ROOT/agents"

if [ ! -f "$TEAM_TEMPLATE" ] && [ -f "$SCRIPT_ROOT/templates/team.md" ]; then
  TEAM_TEMPLATE="$SCRIPT_ROOT/templates/team.md"
fi
if [ ! -d "$AGENTS_SOURCE_DIR" ] && [ -d "$SCRIPT_ROOT/agents" ]; then
  AGENTS_SOURCE_DIR="$SCRIPT_ROOT/agents"
fi

if $CHECK_ONLY; then
  echo "=== Teamwork Skill — Status ==="
  echo ""
  echo "CLI backends:"
  $CODEX_OK && ok "  codex CLI found ($(which codex))" || warn "  codex CLI not found (optional)"
  $COPILOT_OK && ok "  copilot CLI found ($(which copilot))" || warn "  copilot CLI not found (optional)"
  if ! $CODEX_OK && ! $COPILOT_OK; then
    warn "  Neither CLI found — will use Claude-native fallback"
  fi
  has_recursive_cache && warn "  Recursive teamwork cache detected (may cause intermittent 529 errors)" || true

  echo ""
  echo "Marketplaces ($SETTINGS):"
  if [ -f "$SETTINGS" ]; then
    python3 -c "
import json, sys
s = json.load(open(sys.argv[1]))
m = s.get('extraKnownMarketplaces', {})
print('  \033[0;32m✓\033[0m openai-codex registered'  if 'openai-codex'   in m else '  \033[1;33m!\033[0m openai-codex not registered')
print('  \033[0;32m✓\033[0m copilot-local registered' if 'copilot-local' in m else '  \033[1;33m!\033[0m copilot-local not registered')
" "$SETTINGS"
  else
    warn "  settings.json not found"
  fi

  echo ""
  if [ -n "$REPO_ROOT" ]; then
    echo "Repo config:"
    [ -f "$TEAM_MD" ] && ok "  .claude/team.md present" || warn "  .claude/team.md missing (run setup to create)"
    HOOK_DEST="$REPO_ROOT/.git/hooks/post-commit"
    if [ -f "$HOOK_DEST" ] && grep -q "teamwork post-commit" "$HOOK_DEST" 2>/dev/null; then
      ok "  .git/hooks/post-commit installed (teamwork auto push+PR)"
    elif [ -f "$HOOK_DEST" ]; then
      warn "  .git/hooks/post-commit exists but is not a teamwork hook"
    else
      warn "  .git/hooks/post-commit missing (run setup --repo to install)"
    fi
  fi

  echo ""
  echo "Codex native skill discovery:"
  if [ -e "$HOME/.agents/skills/teamwork" ]; then
    ok "  ~/.agents/skills/teamwork present"
  else
    warn "  ~/.agents/skills/teamwork missing (needed for native Codex skill discovery)"
  fi
  exit 0
fi

echo "=== Teamwork Setup ==="
echo "Mode: $MODE"
echo ""

if has_recursive_cache; then
  warn "Recursive teamwork plugin cache detected under $TEAMWORK_CACHE_ROOT."
  if is_from_cache; then
    info "Running from cache — cannot auto-clean. Manual fix:"
    info "  rm -rf \"$TEAMWORK_CACHE_ROOT\" && /reload-plugins"
  else
    rm -rf "$TEAMWORK_CACHE_ROOT"
    ok "Cleared recursive teamwork cache."
    info "Run /reload-plugins to reload plugins."
  fi
  echo ""
fi

echo "Registering plugin marketplaces in $SETTINGS"
if [ ! -f "$SETTINGS" ]; then
  warn "settings.json not found — skipping marketplace registration."
else
  python3 - "$SETTINGS" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
m = s.setdefault("extraKnownMarketplaces", {})
changed = False
if "openai-codex" not in m:
    m["openai-codex"] = {"source": {"source": "github", "repo": "openai/codex-plugin-cc"}}
    changed = True
    print("  + openai-codex marketplace registered")
else:
    print("  \033[0;32m✓\033[0m openai-codex already registered")
if "copilot-local" not in m:
    m["copilot-local"] = {"source": {"source": "github", "repo": "LeePepe/copilot-plugin-cc"}}
    changed = True
    print("  + copilot-local marketplace registered")
else:
    print("  \033[0;32m✓\033[0m copilot-local already registered")
if changed:
    with open(path, "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
        f.write("\n")
PYEOF
fi

if [ "$MODE" = "repo" ] && [ -n "$REPO_ROOT" ] && [ ! -f "$TEAM_MD" ]; then
  echo ""
  mkdir -p "$(dirname "$TEAM_MD")"
  if [ -f "$TEAM_TEMPLATE" ]; then
    cp "$TEAM_TEMPLATE" "$TEAM_MD"
    ok "Created .claude/team.md (from template)"
    info "Edit it to customize executor routing, review mode, and verification commands."
  else
    warn "Template not found: $TEAM_TEMPLATE"
  fi
fi

# Install post-commit hook (repo mode only)
if [ "$MODE" = "repo" ] && [ -n "$REPO_ROOT" ]; then
  HOOK_SRC="$PLUGIN_ROOT/scripts/post-commit-hook.sh"
  if [ ! -f "$HOOK_SRC" ] && [ -f "$SCRIPT_ROOT/scripts/post-commit-hook.sh" ]; then
    HOOK_SRC="$SCRIPT_ROOT/scripts/post-commit-hook.sh"
  fi
  HOOK_DEST="$REPO_ROOT/.git/hooks/post-commit"
  echo ""
  echo "Installing post-commit hook:"
  if [ ! -f "$HOOK_SRC" ]; then
    warn "  post-commit-hook.sh not found — skipping hook installation."
  elif [ -f "$HOOK_DEST" ] && ! grep -q "teamwork post-commit" "$HOOK_DEST" 2>/dev/null; then
    warn "  .git/hooks/post-commit already exists and is not a teamwork hook — skipping to avoid overwrite."
    info "  To install manually: append contents of scripts/post-commit-hook.sh to .git/hooks/post-commit"
  else
    cp "$HOOK_SRC" "$HOOK_DEST"
    chmod +x "$HOOK_DEST"
    ok "  Installed .git/hooks/post-commit (auto push + PR)"
  fi
fi

if $FULL_AGENTS; then
  echo ""
  echo "Installing all agents to $AGENTS_DIR/ (legacy eager-load mode):"
  mkdir -p "$AGENTS_DIR"
  if [ ! -d "$AGENTS_SOURCE_DIR" ]; then
    fail "Agents source directory not found: $AGENTS_SOURCE_DIR"
    exit 1
  fi
  for f in "$AGENTS_SOURCE_DIR"/*.md; do
    [ -f "$f" ] || continue
    agent="$(basename "$f" .md)"
    cp "$f" "$AGENTS_DIR/$agent.md"
    ok "  $agent.md"
  done
fi

echo ""
if $CODEX_OK; then
  ok "codex CLI found ($(which codex))"
else
  info "codex CLI not found (optional). Install it and ensure it is in PATH."
fi
if $COPILOT_OK; then
  ok "copilot CLI found ($(which copilot))"
else
  info "copilot CLI not found (optional). Install it and ensure it is in PATH."
fi
if ! $CODEX_OK && ! $COPILOT_OK; then
  echo ""
  warn "Neither CLI found — teamwork will use Claude-native fallback."
fi

echo ""
ok "Setup complete."
if [ "$MODE" = "repo" ] && [ -n "$REPO_ROOT" ]; then
  echo ""
  info "Per-repo config: $TEAM_MD"
  info "Edit it to customize executor routing, review mode, and verification commands."
fi
