#!/usr/bin/env bash
# setup.sh — Install teamwork agents, skill file, and register plugin marketplaces.
#
# Usage:
#   ./scripts/setup.sh [--global] [--repo] [--check] [--full-agents]
#
#   --global   Install agents and skill to ~/.claude/
#   --repo     Install agents and skill to .claude/ in current git repo (default)
#   --check    Only check status, don't install anything
#   --full-agents  Preload all runtime agents into .claude/agents (legacy mode)

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
PLUGINS_CACHE="$HOME/.claude/plugins/cache"
TEAMWORK_CACHE_ROOT="$PLUGINS_CACHE/teamwork"

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "  $*"; }

# ── Args ─────────────────────────────────────────────────────────────────────
MODE="repo"
CHECK_ONLY=false
FULL_AGENTS=false
for arg in "$@"; do
  case $arg in
    --global) MODE="global" ;;
    --repo)   MODE="repo" ;;
    --check)  CHECK_ONLY=true ;;
    --full-agents) FULL_AGENTS=true ;;
    *)
      fail "Unknown argument: $arg"
      info "Accepted values: --global, --repo, --check, --full-agents"
      exit 1
      ;;
  esac
done

BOOTSTRAP_AGENTS=(team-lead)
RUNTIME_AGENTS=(research-lead researcher planner plan-reviewer designer fullstack-engineer verifier final-reviewer git-monitor pm security-reviewer devil-advocate a11y-reviewer perf-reviewer user-perspective)
ALL_AGENTS=("${BOOTSTRAP_AGENTS[@]}" "${RUNTIME_AGENTS[@]}")

# ── Paths ────────────────────────────────────────────────────────────────────
if [ "$MODE" = "repo" ]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -z "$REPO_ROOT" ]; then
    fail "--repo requires running inside a git repository. Use --global outside a repo."
    exit 1
  fi
  AGENTS_DIR="$REPO_ROOT/.claude/agents"
  SKILL_DEST="$REPO_ROOT/.claude/skills/teamwork"
  TEAM_MD="$REPO_ROOT/.claude/team.md"
else
  AGENTS_DIR="$HOME/.claude/agents"
  SKILL_DEST="$HOME/.claude/skills/teamwork"
  TEAM_MD=""
fi

# ── Teamwork cache health ─────────────────────────────────────────────────────
is_running_from_teamwork_cache() {
  case "$SKILL_DIR" in
    "$TEAMWORK_CACHE_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

has_recursive_teamwork_cache() {
  [ -d "$TEAMWORK_CACHE_ROOT" ] || return 1
  local hit
  hit=$(find "$TEAMWORK_CACHE_ROOT" -type d -path "*/teamwork/*/teamwork/*" -print -quit 2>/dev/null || true)
  [ -n "$hit" ]
}

maybe_cleanup_recursive_teamwork_cache() {
  if ! has_recursive_teamwork_cache; then
    return 0
  fi

  echo ""
  warn "Detected recursive teamwork plugin cache under $TEAMWORK_CACHE_ROOT."
  warn "This can increase context load and trigger intermittent 529 overloaded_error."

  if is_running_from_teamwork_cache; then
    info "Running from teamwork plugin cache; skip auto-clean to avoid deleting the active script."
    info "Manual fix: rm -rf \"$TEAMWORK_CACHE_ROOT\" && /reload-plugins"
    return 0
  fi

  rm -rf "$TEAMWORK_CACHE_ROOT"
  ok "Cleared recursive teamwork cache."
  info "Reload plugins in Claude Code: /reload-plugins"
}

# ── Check plugins ────────────────────────────────────────────────────────────
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

# ── Check mode ───────────────────────────────────────────────────────────────
if $CHECK_ONLY; then
  STATUS_OK=true
  echo "=== Teamwork Skill — Status ==="
  echo ""
  echo "Plugins (optional, Claude fallback works without plugins):"
  $CODEX_OK   && ok "  codex plugin installed"   || warn "  codex plugin not installed (optional)"
  $COPILOT_OK && ok "  copilot plugin installed" || warn "  copilot plugin not installed (optional)"
  if ! $CODEX_OK && ! $COPILOT_OK; then
    warn "  Neither plugin is installed — pipeline will fallback to Claude-native execution/review."
  fi
  if has_recursive_teamwork_cache; then
    warn "  recursive teamwork plugin cache detected (possible source of intermittent 529 overloaded_error)"
    info "  Run: bash scripts/setup.sh --repo   # auto-cleans when safe"
  fi
  echo ""
  echo "Bootstrap agents ($AGENTS_DIR, optional preload):"
  for agent in "${BOOTSTRAP_AGENTS[@]}"; do
    [ -f "$AGENTS_DIR/$agent.md" ] \
      && warn "  $agent.md currently preloaded (higher baseline context)" \
      || ok "  $agent.md not preloaded"
  done
  echo ""
  echo "Runtime agent bundle ($SKILL_DEST/agents):"
  for agent in "${ALL_AGENTS[@]}"; do
    [ -f "$SKILL_DEST/agents/$agent.md" ] \
      && ok "  $agent.md available for lazy-load" \
      || { fail "  $agent.md missing in skill bundle"; STATUS_OK=false; }
  done
  echo ""
  echo "Loaded runtime agents ($AGENTS_DIR, optional):"
  for agent in "${RUNTIME_AGENTS[@]}"; do
    [ -f "$AGENTS_DIR/$agent.md" ] \
      && warn "  $agent.md currently loaded (higher baseline context)" \
      || ok "  $agent.md not preloaded"
  done
  echo ""
  echo "Skill ($SKILL_DEST/SKILL.md):"
  [ -f "$SKILL_DEST/SKILL.md" ] && ok "  SKILL.md installed" || { fail "  SKILL.md missing"; STATUS_OK=false; }
  echo ""
  echo "Tests:"
  [ -f "$SKILL_DIR/test/test-pipeline.sh" ] \
    && ok "  test harness available: bash test/test-pipeline.sh" \
    || warn "  test harness not found"
  echo ""
  echo "Pipeline infrastructure:"
  [ -f "$SKILL_DIR/scripts/pipeline-lib.sh" ] \
    && ok "  pipeline-lib.sh present" \
    || warn "  pipeline-lib.sh missing"
  $STATUS_OK && exit 0 || exit 1
fi

# ── Install agents ───────────────────────────────────────────────────────────
echo "=== Installing Teamwork Skill ==="
echo ""
echo "Mode: $MODE"
echo ""

maybe_cleanup_recursive_teamwork_cache

mkdir -p "$AGENTS_DIR"
echo "Installing bootstrap agents → $AGENTS_DIR/"
for agent in "${BOOTSTRAP_AGENTS[@]}"; do
  cp "$SKILL_DIR/agents/$agent.md" "$AGENTS_DIR/$agent.md"
  ok "  $agent.md"
done

if ! $FULL_AGENTS; then
  echo ""
  echo "Pruning preloaded runtime agents (keeps custom overrides):"
  for agent in "${RUNTIME_AGENTS[@]}"; do
    src="$SKILL_DIR/agents/$agent.md"
    dst="$AGENTS_DIR/$agent.md"
    if [ -f "$dst" ]; then
      if cmp -s "$src" "$dst"; then
        rm -f "$dst"
        ok "  removed preloaded $agent.md (will lazy-load at runtime)"
      else
        warn "  kept custom $agent.md override"
      fi
    else
      ok "  $agent.md already not preloaded"
    fi
  done
else
  echo ""
  echo "Installing runtime agents (legacy eager-load mode):"
  for agent in "${RUNTIME_AGENTS[@]}"; do
    cp "$SKILL_DIR/agents/$agent.md" "$AGENTS_DIR/$agent.md"
    ok "  $agent.md"
  done
fi

# ── Install skill ─────────────────────────────────────────────────────────────
echo ""
echo "Installing skill → $SKILL_DEST/"
mkdir -p "$SKILL_DEST"
cp "$SKILL_DIR/SKILL.md" "$SKILL_DEST/SKILL.md"
ok "  SKILL.md"
mkdir -p "$SKILL_DEST/agents"
for agent in "${ALL_AGENTS[@]}"; do
  cp "$SKILL_DIR/agents/$agent.md" "$SKILL_DEST/agents/$agent.md"
done
ok "  agents bundle (for lazy-load)"

# ── Install pipeline scripts ──────────────────────────────────────────────────
mkdir -p "$SKILL_DEST/scripts"
if [ -f "$SKILL_DIR/scripts/pipeline-lib.sh" ]; then
  cp "$SKILL_DIR/scripts/pipeline-lib.sh" "$SKILL_DEST/scripts/pipeline-lib.sh"
  ok "  pipeline-lib.sh"
fi

# ── Install flow templates ────────────────────────────────────────────────────
mkdir -p "$SKILL_DEST/templates"
for tmpl in "$SKILL_DIR"/templates/flow-*.yaml; do
  [ -f "$tmpl" ] && cp "$tmpl" "$SKILL_DEST/templates/"
done
ok "  flow templates"

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
# Plugins are optional; having both gives best routing flexibility.
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
  warn "Neither plugin is installed. Teamwork will use Claude-native fallback."
  info "Install codex:  /plugin install codex@openai-codex"
  info "Install copilot: /plugin install copilot@copilot-local"
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
  info "Edit it to customize executor routing, review mode, and verification commands."
fi
