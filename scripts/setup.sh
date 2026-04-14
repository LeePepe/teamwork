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

find_companion_script() {
  local script_name="$1"
  find "$HOME/.claude/plugins" -name "$script_name" 2>/dev/null | head -1
}

CODEX_SCRIPT="$(find_companion_script "codex-companion.mjs")"
COPILOT_SCRIPT="$(find_companion_script "copilot-companion.mjs")"
CODEX_OK=false
COPILOT_OK=false
[ -n "$CODEX_SCRIPT" ] && CODEX_OK=true || true
[ -n "$COPILOT_SCRIPT" ] && COPILOT_OK=true || true

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
  echo "Plugins:"
  $CODEX_OK && ok "  codex plugin installed" || warn "  codex plugin not installed (optional)"
  $COPILOT_OK && ok "  copilot plugin installed" || warn "  copilot plugin not installed (optional)"
  if ! $CODEX_OK && ! $COPILOT_OK; then
    warn "  Neither plugin installed — will use Claude-native fallback"
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
NEEDS_RELOAD=false
if $CODEX_OK; then
  ok "codex plugin installed"
else
  info "codex not installed (optional). To install in Claude Code:"
  info "  /plugin install codex@openai-codex"
  NEEDS_RELOAD=true
fi
if $COPILOT_OK; then
  ok "copilot plugin installed"
else
  info "copilot not installed (optional). To install in Claude Code:"
  info "  /plugin install copilot@copilot-local"
  NEEDS_RELOAD=true
fi
if ! $CODEX_OK && ! $COPILOT_OK; then
  echo ""
  warn "Neither plugin installed — teamwork will use Claude-native fallback."
fi
if $NEEDS_RELOAD; then
  echo ""
  info "After installing plugins, run /reload-plugins, then plugin setup commands"
  info "(for example /codex:setup or /copilot:setup)."
fi

echo ""
ok "Setup complete."
if [ "$MODE" = "repo" ] && [ -n "$REPO_ROOT" ]; then
  echo ""
  info "Per-repo config: $TEAM_MD"
  info "Edit it to customize executor routing, review mode, and verification commands."
fi
