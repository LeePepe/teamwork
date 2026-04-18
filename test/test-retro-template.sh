#!/usr/bin/env bash
# test-retro-template.sh — validates that a teamwork-retro markdown file
# contains all 8 mandatory sections declared in skills/teamwork-retro/SKILL.md.
#
# Usage:
#   test/test-retro-template.sh <retro.md>
#   test/test-retro-template.sh            # runs self-test with a fixture
#
# Exit code: 0 on pass, 1 on any missing section.

set -euo pipefail

MANDATORY_SECTIONS=(
  "## 1. Pipeline compliance table"
  "## 2. Files changed"
  "## 3. Commits / PRs"
  "## 4. Verification evidence"
  "## 5. Deviations / degraded modes"
  "## 6. Unresolved follow-ups"
  "## 7. Skill-improvement proposals"
  "## 8. Missing evidence"
)

MANDATORY_HEADER_FIELDS=(
  "Harness mode:"
  "Outcome:"
)

validate_retro_file() {
  local file="$1"
  local missing=()
  if [ ! -f "$file" ]; then
    echo "  ❌ retro file not found: $file"
    return 1
  fi
  local body
  body=$(cat "$file")
  for section in "${MANDATORY_SECTIONS[@]}"; do
    if ! grep -Fq "$section" <<<"$body"; then
      missing+=("$section")
    fi
  done
  for field in "${MANDATORY_HEADER_FIELDS[@]}"; do
    if ! grep -Fq "$field" <<<"$body"; then
      missing+=("header field: $field")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    echo "  ✅ all 8 mandatory sections + header fields present: $file"
    return 0
  fi
  echo "  ❌ missing in $file:"
  for m in "${missing[@]}"; do
    echo "     - $m"
  done
  return 1
}

self_test() {
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  local pass=0 fail=0

  # Fixture 1: fully valid retro
  cat >"$tmp/good.md" <<'EOF'
# Teamwork Retro — test
**Harness mode:** standard
**Outcome:** pass

## 1. Pipeline compliance table
row
## 2. Files changed
row
## 3. Commits / PRs
row
## 4. Verification evidence
row
## 5. Deviations / degraded modes
None
## 6. Unresolved follow-ups
none
## 7. Skill-improvement proposals
none
## 8. Missing evidence
none
EOF
  if validate_retro_file "$tmp/good.md" >/dev/null 2>&1; then
    echo "  ✅ self-test: valid fixture accepted"
    pass=$((pass+1))
  else
    echo "  ❌ self-test: valid fixture rejected"
    fail=$((fail+1))
  fi

  # Fixture 2: missing section 6
  cat >"$tmp/bad.md" <<'EOF'
# Teamwork Retro — test
**Harness mode:** standard
**Outcome:** pass

## 1. Pipeline compliance table
## 2. Files changed
## 3. Commits / PRs
## 4. Verification evidence
## 5. Deviations / degraded modes
## 7. Skill-improvement proposals
## 8. Missing evidence
EOF
  if validate_retro_file "$tmp/bad.md" >/dev/null 2>&1; then
    echo "  ❌ self-test: invalid fixture incorrectly accepted"
    fail=$((fail+1))
  else
    echo "  ✅ self-test: invalid fixture correctly rejected"
    pass=$((pass+1))
  fi

  echo ""
  echo "  self-test results: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

if [ "$#" -eq 0 ]; then
  echo "=== test-retro-template self-test ==="
  self_test
  exit $?
fi

overall=0
for f in "$@"; do
  validate_retro_file "$f" || overall=1
done
exit "$overall"
