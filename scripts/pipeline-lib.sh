#!/usr/bin/env bash
# pipeline-lib.sh — Shared shell functions for tamper protection, state management,
# and flow engine. Sourced by agents/scripts at runtime.
#
# Usage:  source scripts/pipeline-lib.sh
#
# NOTE: Do NOT add set -euo pipefail — this is a sourceable library, not a standalone script.

# ── SHA256 Portability Shim ──────────────────────────────────────────────────

_sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"
  else echo "ERROR: no SHA256 tool found" >&2; return 1; fi
}

# ── Plan Hash ────────────────────────────────────────────────────────────────

plan_hash() { _sha256 "$1" | cut -c1-16; }

# ── Verify Plan Hash ────────────────────────────────────────────────────────

verify_plan_hash() {
  local state_file="$1"
  local plan_file="$2"

  if [ ! -f "$state_file" ]; then
    echo "ERROR: state file not found: $state_file" >&2
    return 1
  fi
  if [ ! -f "$plan_file" ]; then
    echo "ERROR: plan file not found: $plan_file" >&2
    return 1
  fi

  local stored_hash
  stored_hash=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    state = json.load(f)
print(state.get('plan_hash', ''))
" "$state_file")

  local current_hash
  current_hash=$(plan_hash "$plan_file")

  if [ "$stored_hash" = "$current_hash" ]; then
    return 0
  else
    echo "ERROR: plan hash mismatch — stored=$stored_hash current=$current_hash" >&2
    echo "The plan file has been modified since the pipeline state was created." >&2
    return 1
  fi
}

# ── Nonce Generation ────────────────────────────────────────────────────────

generate_nonce() { od -An -tx1 -N8 /dev/urandom | tr -d ' \n'; }

# ── Verify Nonce ─────────────────────────────────────────────────────────────

verify_nonce() {
  local state_file="$1"
  local nonce="$2"

  if [ ! -f "$state_file" ]; then
    echo "ERROR: state file not found: $state_file" >&2
    return 1
  fi

  local stored_nonce
  stored_nonce=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    state = json.load(f)
print(state.get('_write_nonce', ''))
" "$state_file")

  if [ "$stored_nonce" = "$nonce" ]; then
    return 0
  else
    echo "ERROR: nonce mismatch — provided nonce does not match state file" >&2
    return 1
  fi
}

# ── Init Pipeline State ─────────────────────────────────────────────────────

init_pipeline_state() {
  local plan_path="$1"
  local max_pipeline_steps="${2:-20}"

  if [ ! -f "$plan_path" ]; then
    echo "ERROR: plan file not found: $plan_path" >&2
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
  local state_dir="$repo_root/.claude"
  local state_file="$state_dir/pipeline-state.json"

  mkdir -p "$state_dir"

  local hash
  hash=$(plan_hash "$plan_path")
  local nonce
  nonce=$(generate_nonce)

  local tmp_file="${state_file}.tmp.$$"
  python3 -c "
import json, sys, datetime

state = {
    'plan_path': sys.argv[1],
    'plan_hash': sys.argv[2],
    '_write_nonce': sys.argv[3],
    '_written_by': 'pipeline',
    'current_stage': 'init',
    'completed_stages': [],
    'pending_stages': [],
    'stage_history': [],
    'created_at': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'pipeline_steps': 0,
    'review_loops': 0,
    'repair_count': 0,
    'max_pipeline_steps': int(sys.argv[5]) if len(sys.argv) > 5 else 20
}

with open(sys.argv[4], 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
" "$plan_path" "$hash" "$nonce" "$tmp_file" "$max_pipeline_steps"

  mv "$tmp_file" "$state_file"

  # Print nonce to stdout so callers can capture it
  echo "$nonce"
}

# ── Update Stage ─────────────────────────────────────────────────────────────

update_stage() {
  local state_file="$1"
  local new_stage="$2"
  local nonce="$3"

  if ! verify_nonce "$state_file" "$nonce"; then
    return 1
  fi

  local tmp_file="${state_file}.tmp.$$"
  python3 -c "
import json, sys, datetime

state_file = sys.argv[1]
new_stage = sys.argv[2]
tmp_file = sys.argv[3]

with open(state_file) as f:
    state = json.load(f)

max_steps = int(state.get('max_pipeline_steps', 20))
steps = state.get('pipeline_steps', 0)
if steps >= max_steps:
    print('ERROR: max pipeline steps ({}) exceeded — pipeline halted'.format(max_steps), file=sys.stderr)
    sys.exit(1)

# Record previous stage in history
old_stage = state.get('current_stage', '')
timestamp = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
state['stage_history'].append({
    'from': old_stage,
    'to': new_stage,
    'timestamp': timestamp
})

# Move old stage to completed if not already there and not empty
if old_stage and old_stage != 'init' and old_stage not in state['completed_stages']:
    state['completed_stages'].append(old_stage)

state['current_stage'] = new_stage
state['pipeline_steps'] = steps + 1

with open(tmp_file, 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
" "$state_file" "$new_stage" "$tmp_file"

  local rc=$?
  if [ $rc -ne 0 ]; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$state_file"
}

# ── Detect Oscillation ──────────────────────────────────────────────────────

detect_oscillation() {
  local state_file="$1"

  if [ ! -f "$state_file" ]; then
    echo "ERROR: state file not found: $state_file" >&2
    return 1
  fi

  python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    state = json.load(f)

history = state.get('stage_history', [])

# Get last 6 'to' entries
recent = [e['to'] for e in history[-6:]]

if len(recent) >= 4:
    # Check for A->B->A->B pattern (alternating)
    for i in range(len(recent) - 3):
        a, b, c, d = recent[i], recent[i+1], recent[i+2], recent[i+3]
        if a == c and b == d and a != b:
            print('WARNING: oscillation detected — stages {} and {} are alternating'.format(a, b), file=sys.stderr)
            sys.exit(1)

sys.exit(0)
" "$state_file"
}

# ── Check Review Independence ────────────────────────────────────────────────

check_review_independence() {
  local file1="$1"
  local file2="$2"

  if [ ! -f "$file1" ]; then
    echo "ERROR: reviewer output file not found: $file1" >&2
    return 1
  fi
  if [ ! -f "$file2" ]; then
    echo "ERROR: reviewer output file not found: $file2" >&2
    return 1
  fi

  python3 -c "
import sys
from difflib import SequenceMatcher

with open(sys.argv[1]) as f:
    text1 = f.read()
with open(sys.argv[2]) as f:
    text2 = f.read()

ratio = SequenceMatcher(None, text1, text2).ratio()

if ratio > 0.95:
    print('WARNING: reviewer outputs are {:.1%} similar — reviews may not be independent'.format(ratio), file=sys.stderr)
    sys.exit(1)

sys.exit(0)
" "$file1" "$file2"
}

# ── Enforce Repair Budget ────────────────────────────────────────────────────

enforce_repair_budget() {
  local state_file="$1"
  local nonce="$2"

  if ! verify_nonce "$state_file" "$nonce"; then
    return 1
  fi

  local tmp_file="${state_file}.tmp.$$"
  python3 -c "
import json, sys

state_file = sys.argv[1]
tmp_file = sys.argv[2]

with open(state_file) as f:
    state = json.load(f)

repair_count = state.get('repair_count', 0)
if repair_count >= 1:
    print('ERROR: repair budget exhausted (repair_count={}) — no more repairs allowed'.format(repair_count), file=sys.stderr)
    sys.exit(1)

state['repair_count'] = repair_count + 1

with open(tmp_file, 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
" "$state_file" "$tmp_file"

  local rc=$?
  if [ $rc -ne 0 ]; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$state_file"
}

# ── Get Gate Verdict ─────────────────────────────────────────────────────────

get_gate_verdict() {
  local reviewer_output="$1"

  python3 -c "
import sys

text = sys.argv[1]

has_red = '🔴' in text or 'FAIL' in text
has_yellow = '🟡' in text or 'ITERATE' in text
has_green = '🟢' in text or 'PASS' in text or 'LGTM' in text

# Priority: red > yellow > green
if has_red:
    print('red')
elif has_yellow:
    print('yellow')
elif has_green:
    print('green')
else:
    # Default to yellow if no markers found
    print('yellow')
" "$reviewer_output"
}

# ── Load Flow Template ───────────────────────────────────────────────────────

load_flow_template() {
  local template_path="$1"

  if [ ! -f "$template_path" ]; then
    echo "ERROR: template file not found: $template_path" >&2
    return 1
  fi

  python3 -c "
import sys, os

template_path = sys.argv[1]

# Try yaml.safe_load first, fall back to line-based parsing
try:
    import yaml
    with open(template_path) as f:
        data = yaml.safe_load(f)

    print('name={}'.format(data.get('name', '')))
    print('max_pipeline_steps={}'.format(data.get('max_pipeline_steps', 15)))
    print('max_review_loops={}'.format(data.get('max_review_loops', 3)))

    nodes = data.get('nodes', [])
    if isinstance(nodes, list):
        if nodes and isinstance(nodes[0], dict):
            node_names = [n.get('name', n.get('id', '')) for n in nodes]
        else:
            node_names = [str(n) for n in nodes]
    else:
        node_names = []
    print('nodes={}'.format(','.join(node_names)))

    edges = data.get('edges', [])
    if isinstance(edges, list):
        for e in edges:
            if isinstance(e, dict):
                fr = e.get('from', '')
                to = e.get('to', '')
                cond = e.get('condition', 'always')
                print('edge_{}_{}={}'.format(fr, to, cond))
    elif isinstance(edges, dict):
        for key, val in edges.items():
            print('edge_{}={}'.format(key, val))

except ImportError:
    # Fallback: line-based parsing for simple YAML
    with open(template_path) as f:
        lines = f.readlines()

    name = ''
    max_steps = '15'
    max_loops = '3'
    nodes = []
    edges = []
    in_nodes = False
    in_edges = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('name:'):
            name = stripped.split(':', 1)[1].strip().strip('\"').strip(\"'\")
            in_nodes = False
            in_edges = False
        elif stripped.startswith('max_pipeline_steps:'):
            max_steps = stripped.split(':', 1)[1].strip()
            in_nodes = False
            in_edges = False
        elif stripped.startswith('max_review_loops:'):
            max_loops = stripped.split(':', 1)[1].strip()
            in_nodes = False
            in_edges = False
        elif stripped == 'nodes:':
            in_nodes = True
            in_edges = False
        elif stripped == 'edges:':
            in_edges = True
            in_nodes = False
        elif in_nodes and stripped.startswith('- '):
            val = stripped[2:].strip()
            # Handle '- name: foo' style
            if ':' in val and val.startswith('name:'):
                val = val.split(':', 1)[1].strip().strip('\"').strip(\"'\")
            elif ':' in val:
                # It might be '- {name: foo}' or just '- foo'
                pass
            nodes.append(val)
        elif in_edges and stripped.startswith('- '):
            edges.append(stripped[2:].strip())
        elif not stripped.startswith('-') and ':' not in stripped:
            in_nodes = False
            in_edges = False

    print('name={}'.format(name))
    print('max_pipeline_steps={}'.format(max_steps))
    print('max_review_loops={}'.format(max_loops))
    print('nodes={}'.format(','.join(nodes)))

    for e in edges:
        # Try to parse 'from: x, to: y, condition: z' or '{from: x, to: y}'
        e = e.strip('{}')
        parts = {}
        for p in e.split(','):
            if ':' in p:
                k, v = p.split(':', 1)
                parts[k.strip()] = v.strip().strip('\"').strip(\"'\")
        if 'from' in parts and 'to' in parts:
            cond = parts.get('condition', 'always')
            print('edge_{}_{}={}'.format(parts['from'], parts['to'], cond))
" "$template_path"
}

# ── Render Flow ASCII ────────────────────────────────────────────────────────

render_flow_ascii() {
  local current_node="$1"
  local completed_nodes="$2"  # comma-separated
  local all_nodes="$3"        # comma-separated

  python3 -c "
import sys

current = sys.argv[1]
completed = set(sys.argv[2].split(',')) if sys.argv[2] else set()
all_nodes = sys.argv[3].split(',') if sys.argv[3] else []

parts = []
for node in all_nodes:
    node = node.strip()
    if not node:
        continue
    if node in completed:
        parts.append('[✅ {}]'.format(node))
    elif node == current:
        parts.append('[▶ {}]'.format(node))
    else:
        parts.append('[○ {}]'.format(node))

print(' → '.join(parts))
" "$current_node" "$completed_nodes" "$all_nodes"
}

# ── Resume Pipeline ──────────────────────────────────────────────────────────

resume_pipeline() {
  local state_file="${1:-}"

  if [ -z "$state_file" ]; then
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    state_file="$repo_root/.claude/pipeline-state.json"
  fi

  if [ ! -f "$state_file" ]; then
    echo "fresh"
    return 0
  fi

  # Read plan_path from state, then verify hash
  local plan_path
  plan_path=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    state = json.load(f)
print(state.get('plan_path', ''))
" "$state_file")

  if [ -z "$plan_path" ] || [ ! -f "$plan_path" ]; then
    echo "restart"
    return 0
  fi

  if verify_plan_hash "$state_file" "$plan_path" 2>/dev/null; then
    echo "resume"
  else
    echo "restart"
  fi
}

# ── Save Pipeline State ─────────────────────────────────────────────────────

save_pipeline_state() {
  local state_json="$1"
  local state_file="$2"

  local state_dir
  state_dir=$(dirname "$state_file")
  mkdir -p "$state_dir"

  local tmp_file="${state_file}.tmp.$$"
  printf '%s\n' "$state_json" > "$tmp_file"
  mv "$tmp_file" "$state_file"
}

# ── Cleanup Pipeline State ───────────────────────────────────────────────────

cleanup_pipeline_state() {
  local state_file="${1:-}"

  if [ -z "$state_file" ]; then
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    state_file="$repo_root/.claude/pipeline-state.json"
  fi

  if [ -f "$state_file" ]; then
    rm -f "$state_file"
  fi
}

# ── Pipeline State Helpers ───────────────────────────────────────────────────

get_pipeline_field() {
  local state_file="$1"
  local field_name="$2"

  if [ ! -f "$state_file" ]; then
    echo ""
    return 0
  fi

  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    state = json.load(f)
val = state.get(sys.argv[2], '')
if isinstance(val, list):
    print(','.join(str(x) for x in val))
else:
    print(val)
" "$state_file" "$field_name"
}

get_current_stage() {
  local state_file="${1:-}"
  if [ -z "$state_file" ]; then
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    state_file="$repo_root/.claude/pipeline-state.json"
  fi
  get_pipeline_field "$state_file" "current_stage"
}

# ── Harness Mode Detection ──────────────────────────────────────────────────
# Prints one of: standard | degraded-single-operator | degraded-no-subagent
# Heuristics (any trigger downgrades):
#   - non-TTY stdin (e.g. `claude -p` piped) → degraded-single-operator
#   - CLAUDE_P_NONINTERACTIVE env flag        → degraded-single-operator
#   - CI env flag                             → degraded-single-operator
#   - ALLOWED_TOOLS set but lacks "Agent"     → degraded-no-subagent
# Override: TEAMWORK_ALLOW_DEGRADED=1 does NOT change the reported mode;
#   callers (team-lead Step 0) decide whether to proceed anyway.
detect_harness_mode() {
  # Tool-list probe — most specific signal
  if [ -n "${ALLOWED_TOOLS:-}" ]; then
    case ",$ALLOWED_TOOLS," in
      *,Agent,*) : ;;
      *) echo "degraded-no-subagent"; return 0 ;;
    esac
  fi
  # Non-interactive harness probes
  if [ -n "${CLAUDE_P_NONINTERACTIVE:-}" ] || [ -n "${CI:-}" ] || [ ! -t 0 ]; then
    echo "degraded-single-operator"
    return 0
  fi
  echo "standard"
}

# ── Derive PR_REQUIRED ───────────────────────────────────────────────────────
# Args: <shared_branch_bool> <plan_ship_mode> <team_md_review_mode>
#   shared_branch_bool: "true"|"false"
#   plan_ship_mode:     e.g. "pr"|"local"|"" (empty ok)
#   team_md_review_mode: e.g. "pr"|"local"|"" (empty ok)
# Prints "true" if any of: shared==true, plan==pr, team_md==pr; else "false".
derive_pr_required() {
  local shared="${1:-false}"
  local plan_ship="${2:-}"
  local team_review="${3:-}"
  if [ "$shared" = "true" ] || [ "$plan_ship" = "pr" ] || [ "$team_review" = "pr" ]; then
    echo "true"
  else
    echo "false"
  fi
}
