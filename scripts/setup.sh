#!/usr/bin/env bash
# setup.sh — Install planning-team-skill agents, skill file, and register plugin marketplaces.
#
# Usage:
#   ./scripts/setup.sh [--global] [--repo] [--check]
#
#   --global   Install agents and skill to ~/.claude/
#   --repo     Install agents and skill to .claude/ in current git repo (default)
#   --check    Only check status, don't install anything

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
PLUGINS_CACHE="$HOME/.claude/plugins/cache"

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "  $*"; }

# ── Args ─────────────────────────────────────────────────────────────────────
MODE="repo"
CHECK_ONLY=false
for arg in "$@"; do
  case $arg in
    --global) MODE="global" ;;
    --repo)   MODE="repo" ;;
    --check)  CHECK_ONLY=true ;;
  esac
done

# ── Paths ────────────────────────────────────────────────────────────────────
if [ "$MODE" = "repo" ]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -z "$REPO_ROOT" ]; then
    fail "--repo requires running inside a git repository. Use --global outside a repo."
    exit 1
  fi
  AGENTS_DIR="$REPO_ROOT/.claude/agents"
  SKILL_DEST="$REPO_ROOT/.claude/skills/planning-team"
  TEAM_MD="$REPO_ROOT/.claude/team.md"
else
  AGENTS_DIR="$HOME/.claude/agents"
  SKILL_DEST="$HOME/.claude/skills/planning-team"
  TEAM_MD=""
fi

# ── Check plugins ────────────────────────────────────────────────────────────
check_plugin() {
  local name="$1"
  local cache_pattern="$2"
  if ls "$PLUGINS_CACHE/$cache_pattern" 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

CODEX_OK=false
COPILOT_OK=false
check_plugin "codex" "openai-codex" && CODEX_OK=true || true
check_plugin "copilot" "copilot-local" && COPILOT_OK=true || true

# ── Check mode ───────────────────────────────────────────────────────────────
if $CHECK_ONLY; then
  echo "=== Planning Team Skill — Status ==="
  echo ""
  echo "Plugins (at least one required):"
  $CODEX_OK   && ok "  codex plugin installed"   || warn "  codex plugin not installed (optional)"
  $COPILOT_OK && ok "  copilot plugin installed" || warn "  copilot plugin not installed (optional)"
  if ! $CODEX_OK && ! $COPILOT_OK; then
    fail "  Neither plugin is installed — at least one is required."
  fi
  echo ""
  echo "Agents ($AGENTS_DIR):"
  for agent in team-lead planner plan-reviewer codex-coder copilot; do
    [ -f "$AGENTS_DIR/$agent.md" ] \
      && ok "  $agent.md" \
      || fail "  $agent.md missing"
  done
  echo ""
  echo "Skill ($SKILL_DEST/SKILL.md):"
  [ -f "$SKILL_DEST/SKILL.md" ] && ok "  SKILL.md installed" || fail "  SKILL.md missing"
  exit 0
fi

# ── Install agents ───────────────────────────────────────────────────────────
echo "=== Installing Planning Team Skill ==="
echo ""
echo "Mode: $MODE"
echo ""

echo "Installing agent definitions → $AGENTS_DIR/"
mkdir -p "$AGENTS_DIR"
for f in "$SKILL_DIR/agents/"*.md; do
  cp "$f" "$AGENTS_DIR/"
  ok "  $(basename $f)"
done

# ── Install skill ─────────────────────────────────────────────────────────────
echo ""
echo "Installing skill → $SKILL_DEST/"
mkdir -p "$SKILL_DEST"
cp "$SKILL_DIR/SKILL.md" "$SKILL_DEST/SKILL.md"
ok "  SKILL.md"

# ── Install team.md template (repo mode only) ─────────────────────────────────
if [ "$MODE" = "repo" ] && [ -n "$TEAM_MD" ] && [ ! -f "$TEAM_MD" ]; then
  mkdir -p "$(dirname $TEAM_MD)"
  cp "$SKILL_DIR/templates/team.md" "$TEAM_MD"
  ok "  .claude/team.md (template)"
fi

# ── Register plugin marketplaces in settings.json ────────────────────────────
echo ""
echo "Registering plugin marketplaces in $SETTINGS"

if [ ! -f "$SETTINGS" ]; then
  warn "settings.json not found, skipping marketplace registration."
else
  python3 - "$SETTINGS" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    s = json.load(f)

markets = s.setdefault("extraKnownMarketplaces", {})

changed = False

if "openai-codex" not in markets:
    markets["openai-codex"] = {
        "source": {"source": "github", "repo": "openai/codex-plugin-cc"}
    }
    changed = True
    print("  + openai-codex marketplace registered")
else:
    print("  ✓ openai-codex marketplace already registered")

if "copilot-local" not in markets:
    markets["copilot-local"] = {
        "source": {"source": "github", "repo": "LeePepe/copilot-plugin-cc"}
    }
    changed = True
    print("  + copilot-local marketplace registered")
else:
    print("  ✓ copilot-local marketplace already registered")

if changed:
    with open(path, "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
        f.write("\n")
PYEOF
fi

# ── Plugin install instructions ───────────────────────────────────────────────
# At least one plugin is required; having both is recommended.
echo ""
NEEDS_RELOAD=false

if $CODEX_OK; then
  ok "codex plugin already installed"
else
  info "codex plugin not installed (optional). To install, run in Claude Code:"
  info "  /plugin install codex@openai-codex"
  NEEDS_RELOAD=true
fi

if $COPILOT_OK; then
  ok "copilot plugin already installed"
else
  info "copilot plugin not installed (optional). To install, run in Claude Code:"
  info "  /plugin install copilot@copilot-local"
  NEEDS_RELOAD=true
fi

if ! $CODEX_OK && ! $COPILOT_OK; then
  echo ""
  fail "Neither plugin is installed. At least one is required to use this skill."
  info "Install codex:  /plugin install codex@openai-codex"
  info "Install copilot: /plugin install copilot@copilot-local"
  NEEDS_RELOAD=true
fi

if $NEEDS_RELOAD; then
  echo ""
  info "After installing plugins, run /reload-plugins, then the setup command"
  info "for each installed plugin (e.g. /codex:setup or /copilot:setup)."
fi

echo ""
ok "Setup complete."
if [ "$MODE" = "repo" ]; then
  echo ""
  info "Per-repo team config: $TEAM_MD"
  info "Edit it to customize executor routing and review mode."
fi
