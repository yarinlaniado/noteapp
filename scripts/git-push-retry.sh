#!/bin/bash
set -euo pipefail
# Usage: git-push-retry.sh "<commit message>" [file...]
# Stages the given files (or whatever's already staged, if none given),
# commits, and pushes to the current branch with a fetch+rebase retry loop
# — survives races against concurrent writers (other CI runs, the TTL
# CronJob) that are all committing to the same gitops/ tree on main.

commit_msg="$1"
shift || true

if [ "$#" -gt 0 ]; then
  git add "$@"
fi

git commit -m "$commit_msg"

branch=$(git rev-parse --abbrev-ref HEAD)
max_attempts=5
attempt=0

while [ "$attempt" -lt "$max_attempts" ]; do
  attempt=$((attempt + 1))
  if git push origin "HEAD:$branch"; then
    echo "pushed on attempt $attempt"
    exit 0
  fi
  echo "push rejected, rebasing and retrying (attempt $attempt/$max_attempts)"
  git fetch origin "$branch"
  git rebase "origin/$branch"
  sleep $((attempt * 2))
done

echo "gave up after $max_attempts attempts" >&2
exit 1
