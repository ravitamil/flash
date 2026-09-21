#!/usr/bin/env bash
# Check for upstream releases of InlitX/streak

set -euo pipefail

echo "Checking for latest upstream releases from InlitX/streak..."

RELEASE_JSON=$(curl -s -H "User-Agent: Flash-Upstream-Checker" "https://api.github.com/repos/InlitX/streak/releases" || true)

if [ -z "$RELEASE_JSON" ]; then
  echo "Failed to fetch releases from GitHub API."
  exit 1
fi

LATEST_TAG=$(echo "$RELEASE_JSON" | grep -m1 '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
LATEST_DATE=$(echo "$RELEASE_JSON" | grep -m1 '"published_at":' | sed -E 's/.*"published_at": "([^"]+)".*/\1/')
LATEST_NAME=$(echo "$RELEASE_JSON" | grep -m1 '"name":' | sed -E 's/.*"name": "([^"]+)".*/\1/')

echo "--------------------------------------------------"
echo "Latest Upstream Release: $LATEST_TAG"
echo "Published Date:          $LATEST_DATE"
echo "Release Title:           $LATEST_NAME"
echo "--------------------------------------------------"

if git tag -l | grep -q "^${LATEST_TAG}$"; then
  echo "[OK] You already have tag $LATEST_TAG locally."
else
  echo "[NEW RELEASE DETECTED] Upstream has release $LATEST_TAG!"
  echo "Run the following commands to update:"
  echo "  git fetch upstream --tags"
  echo "  git merge $LATEST_TAG"
fi
