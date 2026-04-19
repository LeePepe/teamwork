#!/usr/bin/env bash
# post-commit-hook.sh — Auto-push and create PR after every commit.
# Installed by setup.sh as .git/hooks/post-commit in any repo using teamwork.
#
# Behavior:
#   1. Push current branch to origin.
#   2. If PR_REQUIRED or branch is not a shared branch, create a PR if none exists.
#   3. Skip silently if no remote, or if already on a shared/protected branch
#      (shared-branch direct commits are a pipeline integrity violation caught earlier).

set -euo pipefail

# Skip during rebase, merge, cherry-pick — hook fires on each replayed commit
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -d "${REPO_ROOT}/.git/rebase-merge" ] || \
   [ -d "${REPO_ROOT}/.git/rebase-apply" ] || \
   [ -f "${REPO_ROOT}/.git/MERGE_HEAD" ]   || \
   [ -f "${REPO_ROOT}/.git/CHERRY_PICK_HEAD" ]; then
  exit 0
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's|refs/remotes/origin/||' || echo "main")

# Shared-branch set — never auto-PR directly from these
SHARED_SET="main master develop $BASE_BRANCH"
is_shared() {
  local b="$1"
  case " $SHARED_SET " in *" $b "*) return 0 ;; esac
  case "$b" in release/*) return 0 ;; esac
  return 1
}

# No remote → skip everything
HAS_REMOTE=$(git remote 2>/dev/null | head -1 || true)
if [ -z "$HAS_REMOTE" ]; then
  exit 0
fi

# Push
git push origin "$CURRENT_BRANCH:refs/heads/$CURRENT_BRANCH" || {
  echo "[teamwork post-commit] WARNING: push failed — skipping PR creation." >&2
  exit 0
}

# Skip PR if on a shared branch (direct commits here are a pipeline violation)
if is_shared "$CURRENT_BRANCH"; then
  echo "[teamwork post-commit] On shared branch '$CURRENT_BRANCH' — skipping PR creation." >&2
  exit 0
fi

# Skip PR if gh CLI not available
if ! command -v gh >/dev/null 2>&1; then
  echo "[teamwork post-commit] gh CLI not found — skipping PR creation." >&2
  exit 0
fi

# Check if PR already exists for this branch
EXISTING_PR=$(gh pr list --head "$CURRENT_BRANCH" --json number --jq '.[0].number' 2>/dev/null || true)
if [ -n "$EXISTING_PR" ]; then
  PR_URL=$(gh pr view "$EXISTING_PR" --json url --jq '.url' 2>/dev/null || true)
  echo "[teamwork post-commit] PR already exists: $PR_URL" >&2
  exit 0
fi

# Derive PR title from latest commit subject
COMMIT_SUBJECT=$(git log -1 --pretty=%s)

# Summarize all commits ahead of base
COMMITS_BODY=$(git log "origin/$BASE_BRANCH..HEAD" --pretty="- %s" 2>/dev/null \
  | head -20 || echo "- $COMMIT_SUBJECT")

gh pr create \
  --base "$BASE_BRANCH" \
  --title "$COMMIT_SUBJECT" \
  --body "$(cat <<EOF
## Summary

$COMMITS_BODY

## Branch

\`$CURRENT_BRANCH\` → \`$BASE_BRANCH\`

---
_Auto-created by teamwork post-commit hook._
EOF
)" && echo "[teamwork post-commit] PR created." >&2 || {
  echo "[teamwork post-commit] WARNING: PR creation failed." >&2
}
