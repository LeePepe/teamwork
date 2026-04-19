#!/usr/bin/env bash
# pr-monitor.sh — Poll a PR for CI failures and new review comments.
# Runs in background after git-monitor creates/detects a PR.
# Emits structured events to stdout; caller pipes to a log file or Monitor tool.
#
# Usage:
#   bash scripts/pr-monitor.sh <pr-number> [poll-interval-seconds] [max-wait-seconds]
#
# Output (one JSON line per event):
#   {"event":"ci_pass","pr":N,"sha":"..."}
#   {"event":"ci_fail","pr":N,"sha":"...","failures":[...]}
#   {"event":"ci_pending","pr":N,"sha":"...","checks":[...]}
#   {"event":"comment","pr":N,"author":"...","body":"...","url":"..."}
#   {"event":"review_requested_changes","pr":N,"author":"...","body":"..."}
#   {"event":"timeout","pr":N,"elapsed_seconds":N}
#   {"event":"error","pr":N,"reason":"..."}

set -euo pipefail

PR_NUMBER="${1:?Usage: pr-monitor.sh <pr-number> [poll-interval] [max-wait]}"
POLL_INTERVAL="${2:-60}"
MAX_WAIT="${3:-3600}"

if ! command -v gh >/dev/null 2>&1; then
  echo "{\"event\":\"error\",\"pr\":$PR_NUMBER,\"reason\":\"gh CLI not found\"}"
  exit 1
fi

# Validate PR exists
if ! gh pr view "$PR_NUMBER" --json number >/dev/null 2>&1; then
  echo "{\"event\":\"error\",\"pr\":$PR_NUMBER,\"reason\":\"PR not found\"}"
  exit 1
fi

SEEN_COMMENTS=""
ELAPSED=0
LAST_SHA=""

_json_escape() {
  # Minimal JSON string escaping
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g' \
    | sed 's/"/\\"/g' \
    | sed 's/$/\\n/' \
    | tr -d '\n' \
    | sed 's/\\n$//'
}

while [ "$ELAPSED" -lt "$MAX_WAIT" ]; do
  # --- Merge conflict check ---
  MERGE_STATUS=$(gh pr view "$PR_NUMBER" --json mergeable,mergeStateStatus \
    --jq '[.mergeable,.mergeStateStatus] | join("|")' 2>/dev/null || true)
  MERGEABLE=$(echo "$MERGE_STATUS" | cut -d'|' -f1)
  MERGE_STATE=$(echo "$MERGE_STATUS" | cut -d'|' -f2)

  if [ "$MERGEABLE" = "CONFLICTING" ] || [ "$MERGE_STATE" = "DIRTY" ]; then
    BASE=$(gh pr view "$PR_NUMBER" --json baseRefName --jq '.baseRefName' 2>/dev/null || echo "main")
    echo "{\"event\":\"merge_conflict\",\"pr\":$PR_NUMBER,\"mergeable\":\"$MERGEABLE\",\"merge_state\":\"$MERGE_STATE\",\"base\":\"$BASE\"}"
    # Conflict is actionable — exit so team-lead can rebase immediately
    exit 0
  fi

  # --- CI checks ---
  SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid' 2>/dev/null || true)

  if [ -n "$SHA" ] && [ "$SHA" != "$LAST_SHA" ]; then
    LAST_SHA="$SHA"

    CI_JSON=$(gh pr checks "$PR_NUMBER" --json name,state,conclusion 2>/dev/null || echo "[]")

    PENDING=$(echo "$CI_JSON" | python3 -c "
import json,sys
checks=json.load(sys.stdin)
print(len([c for c in checks if c.get('state') in ('PENDING','IN_PROGRESS','QUEUED','WAITING','REQUESTED','EXPECTED')]))
" 2>/dev/null || echo "0")

    FAILURES=$(echo "$CI_JSON" | python3 -c "
import json,sys
checks=json.load(sys.stdin)
failed=[c['name'] for c in checks if c.get('conclusion') in ('FAILURE','ERROR','TIMED_OUT','CANCELLED','ACTION_REQUIRED','STARTUP_FAILURE')]
print(json.dumps(failed))
" 2>/dev/null || echo "[]")

    FAILURE_COUNT=$(echo "$FAILURES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [ "$PENDING" -gt 0 ]; then
      CHECKS_LIST=$(echo "$CI_JSON" | python3 -c "
import json,sys
checks=json.load(sys.stdin)
names=[c['name'] for c in checks if c.get('state') in ('PENDING','IN_PROGRESS','QUEUED','WAITING','REQUESTED','EXPECTED')]
print(json.dumps(names))
" 2>/dev/null || echo "[]")
      echo "{\"event\":\"ci_pending\",\"pr\":$PR_NUMBER,\"sha\":\"$SHA\",\"checks\":$CHECKS_LIST}"
    elif [ "$FAILURE_COUNT" -gt 0 ]; then
      echo "{\"event\":\"ci_fail\",\"pr\":$PR_NUMBER,\"sha\":\"$SHA\",\"failures\":$FAILURES}"
      # CI failed — exit after reporting so team-lead can act immediately
      exit 0
    else
      TOTAL=$(echo "$CI_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
      if [ "$TOTAL" -gt 0 ]; then
        echo "{\"event\":\"ci_pass\",\"pr\":$PR_NUMBER,\"sha\":\"$SHA\"}"
        # CI passed — keep watching for comments
      fi
    fi
  fi

  # --- New comments & review requests ---
  COMMENTS_JSON=$(gh pr view "$PR_NUMBER" --json comments,reviews --jq '
    [
      (.comments // [])[] | {type:"comment", author:.author.login, body:.body, url:(.url // "")},
      (.reviews // [])[]   | select(.state == "CHANGES_REQUESTED") | {type:"review_requested_changes", author:.author.login, body:.body}
    ]
  ' 2>/dev/null || echo "[]")

  while IFS= read -r item; do
    KEY=$(echo "$item" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('author','')+'|'+(d.get('body','')[:80]))" 2>/dev/null || true)
    [ -z "$KEY" ] && continue
    if ! echo "$SEEN_COMMENTS" | grep -qF "$KEY"; then
      SEEN_COMMENTS="$SEEN_COMMENTS
$KEY"
      TYPE=$(echo "$item" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('type','comment'))" 2>/dev/null || echo "comment")
      AUTHOR=$(echo "$item" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('author',''))" 2>/dev/null || echo "")
      BODY=$(echo "$item" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('body',''))" 2>/dev/null || echo "")
      URL=$(echo "$item" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('url',''))" 2>/dev/null || echo "")
      BODY_ESC=$(_json_escape "$BODY")
      echo "{\"event\":\"$TYPE\",\"pr\":$PR_NUMBER,\"author\":\"$AUTHOR\",\"body\":\"$BODY_ESC\",\"url\":\"$URL\"}"
    fi
  done < <(echo "$COMMENTS_JSON" | python3 -c "
import json,sys
items=json.load(sys.stdin)
for item in items:
    print(json.dumps(item))
" 2>/dev/null || true)

  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo "{\"event\":\"timeout\",\"pr\":$PR_NUMBER,\"elapsed_seconds\":$ELAPSED}"
