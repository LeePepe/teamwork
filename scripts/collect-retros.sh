#!/usr/bin/env bash
# collect-retros.sh — Collect ALL retro data into ~/Development/teamwork/data/
#
# Two data sources:
#   1. Hand-written retros:  ~/Development/*/docs/retro/*.md  → data/retros/collected/
#   2. Execution run logs:   ~/Development/*/.claude/last-run-*.md → data/runs.jsonl (via collect_runs.py)
#
# Usage: bash scripts/collect-retros.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEV_DIR="${HOME}/Development"
DATA_DIR="${REPO_ROOT}/data"
RETRO_DIR="${DATA_DIR}/retros/collected"

mkdir -p "$RETRO_DIR"

echo "=== Retro Collection ==="
echo ""

# --- Part 1: Hand-written retros ---
echo "## 1. Hand-written retros"
echo "   Scanning: ${DEV_DIR}/*/docs/retro/*.md"

retro_count=0
for retro_file in "${DEV_DIR}"/*/docs/retro/*.md; do
  [ -f "$retro_file" ] || continue
  project_name="$(basename "$(dirname "$(dirname "$(dirname "$retro_file")")")")"
  base_name="$(basename "$retro_file")"
  dest="${RETRO_DIR}/${project_name}--${base_name}"
  cp "$retro_file" "$dest"
  echo "   Collected: ${project_name}/docs/retro/${base_name}"
  retro_count=$((retro_count + 1))
done
echo "   Total retros: ${retro_count}"
echo ""

# --- Part 2: Execution run logs ---
echo "## 2. Execution run logs"
python3 "${SCRIPT_DIR}/collect_runs.py" --scan-dir "$DEV_DIR" --store "${DATA_DIR}/runs.jsonl"
echo ""

# --- Summary ---
run_count=0
if [ -f "${DATA_DIR}/runs.jsonl" ]; then
  run_count=$(wc -l < "${DATA_DIR}/runs.jsonl" | tr -d ' ')
fi
echo "=== Summary ==="
echo "  Hand-written retros: ${retro_count}"
echo "  Execution run logs:  ${run_count}"
echo "  Data directory:      ${DATA_DIR}/"
