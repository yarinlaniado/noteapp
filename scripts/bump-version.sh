#!/bin/bash
set -euo pipefail
# Usage: bump-version.sh "<commit message>"
# Every commit is a patch bump by default. Writing [MAJOR] or [MINOR]
# (uppercase, brackets required) anywhere in the commit message bumps that
# level instead. Writes the new version back to version.txt and prints it
# to stdout.

commit_msg="${1:-}"
current_version=$(cat version.txt)

IFS='.' read -r major minor patch <<< "$current_version"

major_pattern='\[MAJOR\]'
minor_pattern='\[MINOR\]'

if [[ "$commit_msg" =~ $major_pattern ]]; then
  major=$((major + 1)); minor=0; patch=0
elif [[ "$commit_msg" =~ $minor_pattern ]]; then
  minor=$((minor + 1)); patch=0
else
  patch=$((patch + 1))
fi

new_version="$major.$minor.$patch"
echo "$new_version" > version.txt
echo "$new_version"
