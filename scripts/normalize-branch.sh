#!/bin/bash
# Deterministic, Kubernetes-namespace-safe, Docker-tag-safe branch identifier.
# Usage: source this file, then: normalize_branch "feature/Payment_API"
#
# lowercase -> non-[a-z0-9-] chars become '-' -> collapse/trim dashes ->
# truncate to 57 chars -> append a 5-char content hash. The hash isn't just
# decoration: it removes case-collisions ("Feature/Foo" vs "feature/foo")
# and truncation-collisions (two long branch names sharing a 57-char prefix)
# as entire classes of bug, at the cost of 6 characters. 57 + 1 + 5 = 63,
# exactly the Kubernetes DNS label limit.
normalize_branch() {
  local raw="$1"
  local hash norm

  hash=$(printf '%s' "$raw" | sha1sum | cut -c1-5)

  norm=$(printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-57)
  norm=$(printf '%s' "$norm" | sed -E 's/-+$//') # truncation can leave a trailing dash

  if [ -z "$norm" ]; then
    norm="branch" # e.g. a branch name that's entirely non-alphanumeric
  fi

  printf '%s-%s\n' "$norm" "$hash"
}
