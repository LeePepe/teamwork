#!/usr/bin/env bash
# collect-retros.sh — Collect retrospective files from all personal projects
# Usage: bash scripts/collect-retros.sh [output_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEV_DIR="${HOME}/Development"
OUTPUT_DIR="${1:-${REPO_ROOT}/docs/retro-findings/collected}"

mkdir -p "$OUTPUT_DIR"

echo "=== Retro Collection ==="
echo "Scanning: ${DEV_DIR}/*/docs/retro/*.md"
echo "Output:   ${OUTPUT_DIR}"
echo ""

count=0
for retro_file in "${DEV_DIR}"/*/docs/retro/*.md; do
  [ -f "$retro_file" ] || continue
  project_name="$(basename "$(dirname "$(dirname "$(dirname "$retro_file")")")")"
  base_name="$(basename "$retro_file")"
  dest="${OUTPUT_DIR}/${project_name}--${base_name}"
  cp "$retro_file" "$dest"
  echo "  Collected: ${project_name}/docs/retro/${base_name}"
  count=$((count + 1))
done

echo ""
echo "Total retros collected: ${count}"

if [ "$count" -eq 0 ]; then
  echo "No retro files found. Projects should place retros in docs/retro/*.md"
  echo "Use templates/retro-template.md as a starting point."
fi
