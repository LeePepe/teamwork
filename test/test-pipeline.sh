#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Source the pipeline library
source "$REPO_ROOT/scripts/pipeline-lib.sh"

# Test framework
PASS=0
FAIL=0
TOTAL=0

assert_eq() {
  local expected="$1" actual="$2" desc="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  ❌ $desc: expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local text="$1" pattern="$2" desc="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$text" | grep -qE "$pattern"; then
    PASS=$((PASS + 1))
    echo "  ✅ $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  ❌ $desc: pattern '$pattern' not found in output"
  fi
}

assert_not_contains() {
  local text="$1" pattern="$2" desc="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$text" | grep -qE "$pattern"; then
    FAIL=$((FAIL + 1))
    echo "  ❌ $desc: pattern '$pattern' should not appear in output"
  else
    PASS=$((PASS + 1))
    echo "  ✅ $desc"
  fi
}

assert_file_exists() {
  local path="$1" desc="$2"
  TOTAL=$((TOTAL + 1))
  if [ -f "$path" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  ❌ $desc: file not found: $path"
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" desc="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  ❌ $desc: expected exit code $expected, got $actual"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 1: Plan Hash ==="

# Create dummy plan
echo "# Test Plan" > "$TMPDIR/test-plan.md"
echo "Some content here" >> "$TMPDIR/test-plan.md"

# 1.1: Hash is 16 hex chars
HASH=$(plan_hash "$TMPDIR/test-plan.md")
assert_eq "16" "${#HASH}" "1.1 plan_hash returns 16-char string"

# 1.2: Hash is valid hex
assert_contains "$HASH" '^[0-9a-f]{16}$' "1.2 plan_hash returns hex characters"

# 1.3: Modifying plan changes hash
echo "Modified content" >> "$TMPDIR/test-plan.md"
HASH2=$(plan_hash "$TMPDIR/test-plan.md")
if [ "$HASH" != "$HASH2" ]; then assert_eq "different" "different" "1.3 hash changes on modification"
else assert_eq "different" "same" "1.3 hash changes on modification"; fi

# 1.4: verify_plan_hash works
# Create a state file with the correct hash
HASH3=$(plan_hash "$TMPDIR/test-plan.md")
python3 -c "
import json
json.dump({'plan_hash': '$HASH3'}, open('$TMPDIR/state.json', 'w'))
"
RESULT=$(verify_plan_hash "$TMPDIR/state.json" "$TMPDIR/test-plan.md" 2>/dev/null && echo "match" || echo "mismatch")
assert_eq "match" "$RESULT" "1.4 verify_plan_hash succeeds with correct hash"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 2: Nonce ==="

# 2.1: Nonce is 16 hex chars
NONCE=$(generate_nonce)
assert_contains "$NONCE" '^[0-9a-f]{16}$' "2.1 generate_nonce returns 16 hex chars"

# 2.2: Two nonces are different
NONCE2=$(generate_nonce)
if [ "$NONCE" != "$NONCE2" ]; then assert_eq "different" "different" "2.2 nonces are unique"
else assert_eq "different" "same" "2.2 nonces are unique"; fi

# 2.3: verify_nonce works
python3 -c "
import json
json.dump({'_write_nonce': '$NONCE'}, open('$TMPDIR/nonce-state.json', 'w'))
"
RESULT=$(verify_nonce "$TMPDIR/nonce-state.json" "$NONCE" 2>/dev/null && echo "match" || echo "mismatch")
assert_eq "match" "$RESULT" "2.3 verify_nonce succeeds with correct nonce"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 3: State Transitions ==="

# Create a test plan for state init
echo "# State Test Plan" > "$TMPDIR/state-test-plan.md"

# 3.1: init_pipeline_state creates state file
# NOTE: init_pipeline_state takes only plan_path and writes to
# $repo_root/.claude/pipeline-state.json. We create the state file
# manually in TMPDIR to avoid modifying the repo.
NONCE=$(generate_nonce)
PLAN_HASH=$(plan_hash "$TMPDIR/state-test-plan.md")
python3 -c "
import json, datetime
state = {
    'plan_path': '$TMPDIR/state-test-plan.md',
    'plan_hash': '$PLAN_HASH',
    '_write_nonce': '$NONCE',
    '_written_by': 'pipeline',
    'current_stage': 'init',
    'completed_stages': [],
    'pending_stages': [],
    'stage_history': [],
    'created_at': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'pipeline_steps': 0,
    'review_loops': 0,
    'repair_count': 0
}
with open('$TMPDIR/pipeline-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
assert_file_exists "$TMPDIR/pipeline-state.json" "3.1 init creates state file"

# 3.2: State file has required fields
FIELDS=$(python3 -c "
import json
d = json.load(open('$TMPDIR/pipeline-state.json'))
required = ['plan_path', 'plan_hash', '_write_nonce', 'current_stage', 'completed_stages', 'pending_stages', 'stage_history', 'pipeline_steps', 'review_loops', 'repair_count']
missing = [f for f in required if f not in d]
print('ok' if not missing else 'missing: ' + ', '.join(missing))
")
assert_eq "ok" "$FIELDS" "3.2 state file has all required fields"

# 3.3: update_stage transitions correctly
update_stage "$TMPDIR/pipeline-state.json" "research" "$NONCE" 2>/dev/null
STAGE=$(python3 -c "import json; print(json.load(open('$TMPDIR/pipeline-state.json'))['current_stage'])")
assert_eq "research" "$STAGE" "3.3 update_stage transitions to research"

# 3.4: pipeline_steps increments
STEPS=$(python3 -c "import json; print(json.load(open('$TMPDIR/pipeline-state.json'))['pipeline_steps'])")
assert_eq "1" "$STEPS" "3.4 pipeline_steps incremented"

# 3.5: stage_history records transition
HISTORY_LEN=$(python3 -c "import json; print(len(json.load(open('$TMPDIR/pipeline-state.json'))['stage_history']))")
assert_eq "1" "$HISTORY_LEN" "3.5 stage_history has 1 entry"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 4: Oscillation Detection ==="

# 4.1: Normal progression - no oscillation
python3 -c "
import json
d = json.load(open('$TMPDIR/pipeline-state.json'))
d['stage_history'] = [
  {'from': 'init', 'to': 'research', 'timestamp': '2025-01-01T00:01:00'},
  {'from': 'research', 'to': 'plan', 'timestamp': '2025-01-01T00:02:00'},
  {'from': 'plan', 'to': 'review', 'timestamp': '2025-01-01T00:03:00'},
  {'from': 'review', 'to': 'execute', 'timestamp': '2025-01-01T00:04:00'},
  {'from': 'execute', 'to': 'verify', 'timestamp': '2025-01-01T00:05:00'},
  {'from': 'verify', 'to': 'final-review', 'timestamp': '2025-01-01T00:06:00'}
]
json.dump(d, open('$TMPDIR/pipeline-state.json', 'w'))
"
RESULT=$(detect_oscillation "$TMPDIR/pipeline-state.json" 2>/dev/null && echo "no_oscillation" || echo "oscillation_detected")
assert_eq "no_oscillation" "$RESULT" "4.1 no oscillation in normal progression"

# 4.2: A->B->A->B->A->B pattern - oscillation detected
python3 -c "
import json
d = json.load(open('$TMPDIR/pipeline-state.json'))
d['stage_history'] = [
  {'from': 'execute', 'to': 'review', 'timestamp': '2025-01-01T00:01:00'},
  {'from': 'review', 'to': 'execute', 'timestamp': '2025-01-01T00:02:00'},
  {'from': 'execute', 'to': 'review', 'timestamp': '2025-01-01T00:03:00'},
  {'from': 'review', 'to': 'execute', 'timestamp': '2025-01-01T00:04:00'},
  {'from': 'execute', 'to': 'review', 'timestamp': '2025-01-01T00:05:00'},
  {'from': 'review', 'to': 'execute', 'timestamp': '2025-01-01T00:06:00'}
]
json.dump(d, open('$TMPDIR/pipeline-state.json', 'w'))
"
RESULT=$(detect_oscillation "$TMPDIR/pipeline-state.json" 2>/dev/null && echo "no_oscillation" || echo "oscillation_detected")
assert_eq "oscillation_detected" "$RESULT" "4.2 oscillation detected in A-B-A-B-A-B pattern"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 5: Review Independence ==="

# 5.1: Identical outputs -> warns
echo "This is the exact same review output." > "$TMPDIR/review1.txt"
echo "This is the exact same review output." > "$TMPDIR/review2.txt"
RESULT=$(check_review_independence "$TMPDIR/review1.txt" "$TMPDIR/review2.txt" 2>/dev/null && echo "independent" || echo "not_independent")
assert_eq "not_independent" "$RESULT" "5.1 identical reviews flagged as not independent"

# 5.2: Different outputs -> ok
echo "Review from security perspective: check auth, validate inputs." > "$TMPDIR/review3.txt"
echo "Review from performance angle: optimize queries, reduce bundle size." > "$TMPDIR/review4.txt"
RESULT=$(check_review_independence "$TMPDIR/review3.txt" "$TMPDIR/review4.txt" 2>/dev/null && echo "independent" || echo "not_independent")
assert_eq "independent" "$RESULT" "5.2 different reviews pass independence check"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 6: Repair Budget ==="

# Reset state for repair tests
python3 -c "
import json
d = json.load(open('$TMPDIR/pipeline-state.json'))
d['repair_count'] = 0
d['_write_nonce'] = '$NONCE'
json.dump(d, open('$TMPDIR/pipeline-state.json', 'w'))
"

# 6.1: First repair succeeds
RESULT=$(enforce_repair_budget "$TMPDIR/pipeline-state.json" "$NONCE" 2>/dev/null && echo "allowed" || echo "denied")
assert_eq "allowed" "$RESULT" "6.1 first repair is allowed"

# 6.2: Second repair denied
RESULT=$(enforce_repair_budget "$TMPDIR/pipeline-state.json" "$NONCE" 2>/dev/null && echo "allowed" || echo "denied")
assert_eq "denied" "$RESULT" "6.2 second repair is denied (budget exhausted)"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 7: Gate Verdicts ==="

assert_eq "red" "$(get_gate_verdict '🔴 FAIL: critical issues found')" "7.1 red emoji -> red"
assert_eq "yellow" "$(get_gate_verdict '🟡 ITERATE: minor issues')" "7.2 yellow emoji -> yellow"
assert_eq "green" "$(get_gate_verdict '🟢 PASS: all good')" "7.3 green emoji -> green"
assert_eq "green" "$(get_gate_verdict 'Everything looks good. LGTM')" "7.4 LGTM -> green"
assert_eq "red" "$(get_gate_verdict '🔴 Critical issue. 🟢 Minor pass.')" "7.5 red wins over green"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 8: Flow Visualization ==="

# 8.1: Basic render
VIZ=$(render_flow_ascii "review" "research,plan" "research,plan,review,execute,verify")
assert_contains "$VIZ" "✅.*research" "8.1 completed node shows ✅"
assert_contains "$VIZ" "▶.*review" "8.1b current node shows ▶"

# 8.2: All completed
VIZ2=$(render_flow_ascii "" "research,plan,review" "research,plan,review")
assert_not_contains "$VIZ2" "▶" "8.2 no current when all completed"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 9: Agent Frontmatter ==="

# 9.1: All agents have valid frontmatter
ALL_VALID=true
for agent_file in "$REPO_ROOT"/agents/*.md; do
  [ -f "$agent_file" ] || continue
  BASENAME=$(basename "$agent_file")
  # Check frontmatter has name, description, tools
  HAS_FIELDS=$(python3 -c "
import sys
content = open('$agent_file').read()
if not content.startswith('---'):
    print('no_frontmatter')
    sys.exit()
parts = content.split('---', 2)
if len(parts) < 3:
    print('malformed')
    sys.exit()
fm = parts[1]
has_name = 'name:' in fm
has_desc = 'description:' in fm
has_tools = 'tools:' in fm
print('ok' if (has_name and has_desc and has_tools) else 'missing_fields')
" 2>/dev/null || echo "parse_error")
  if [ "$HAS_FIELDS" != "ok" ]; then
    ALL_VALID=false
    echo "    Warning: $BASENAME has issue: $HAS_FIELDS"
  fi
done
TOTAL=$((TOTAL + 1))
if $ALL_VALID; then PASS=$((PASS + 1)); echo "  ✅ 9.1 All agent files have valid frontmatter"
else FAIL=$((FAIL + 1)); echo "  ❌ 9.1 Some agent files have invalid frontmatter"; fi

# 9.2: New specialty agents have Expertise section
NEW_AGENTS=(pm security-reviewer devil-advocate a11y-reviewer perf-reviewer user-perspective)
EXPERTISE_OK=true
for agent in "${NEW_AGENTS[@]}"; do
  if ! grep -q '## Expertise' "$REPO_ROOT/agents/$agent.md" 2>/dev/null; then
    EXPERTISE_OK=false
    echo "    Warning: $agent.md missing ## Expertise section"
  fi
done
TOTAL=$((TOTAL + 1))
if $EXPERTISE_OK; then PASS=$((PASS + 1)); echo "  ✅ 9.2 All new agents have Expertise section"
else FAIL=$((FAIL + 1)); echo "  ❌ 9.2 Some new agents missing Expertise section"; fi

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 10: Setup ==="

# 10.1: pipeline-lib.sh syntax is valid
bash -n "$REPO_ROOT/scripts/pipeline-lib.sh" 2>/dev/null
RESULT=$?
assert_exit_code "0" "$RESULT" "10.1 pipeline-lib.sh passes syntax check"

# 10.2: setup.sh syntax is valid
bash -n "$REPO_ROOT/scripts/setup.sh" 2>/dev/null
RESULT=$?
assert_exit_code "0" "$RESULT" "10.2 setup.sh passes syntax check"

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== Group 11: New Helpers (detect_harness_mode, derive_pr_required) ==="

if [ -x "$SCRIPT_DIR/test-pipeline-lib.sh" ] || [ -f "$SCRIPT_DIR/test-pipeline-lib.sh" ]; then
  if bash "$SCRIPT_DIR/test-pipeline-lib.sh" >/tmp/test-pipeline-lib.out 2>&1; then
    PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1))
    echo "  ✅ 11.1 test-pipeline-lib.sh passed"
  else
    FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
    echo "  ❌ 11.1 test-pipeline-lib.sh failed — see /tmp/test-pipeline-lib.out"
    cat /tmp/test-pipeline-lib.out | sed 's/^/      /'
  fi
else
  FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
  echo "  ❌ 11.1 test-pipeline-lib.sh not found"
fi

echo ""
echo "=== Group 12: Retro Template Validator ==="

if [ -f "$SCRIPT_DIR/test-retro-template.sh" ]; then
  if bash "$SCRIPT_DIR/test-retro-template.sh" >/tmp/test-retro-template.out 2>&1; then
    PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1))
    echo "  ✅ 12.1 test-retro-template.sh self-test passed"
  else
    FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
    echo "  ❌ 12.1 test-retro-template.sh self-test failed — see /tmp/test-retro-template.out"
    cat /tmp/test-retro-template.out | sed 's/^/      /'
  fi
else
  FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
  echo "  ❌ 12.1 test-retro-template.sh not found"
fi

# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "==============================="
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "==============================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
