#!/bin/bash -e
# Pre-cache commonly used GitHub Actions to avoid download timeouts
#
# The runner uses ACTIONS_RUNNER_ACTION_ARCHIVE_CACHE to find pre-cached actions.
# Format: {owner}_{repo}/{SHA}.tar.gz
#
# When a workflow uses an action, the runner:
# 1. Checks this cache directory for the action and specific commit SHA
# 2. If found: unpacks the cached tar.gz (instant, no download)
# 3. If not found: downloads from GitHub API (slow, can timeout)

CACHE_DIR="/home/runner/action-archive-cache"
mkdir -p "$CACHE_DIR"

# Helper function to cache an action
# Usage: cache_action owner repo ref
cache_action() {
  local owner=$1
  local repo=$2
  local ref=$3

  echo "Caching ${owner}/${repo}@${ref}..."

  # Create directory following {owner}_{repository} naming convention
  local action_dir="$CACHE_DIR/${owner}_${repo}"
  mkdir -p "$action_dir"

  # Clone the repo and get the commit SHA for the ref
  local temp_dir=$(mktemp -d)
  if ! git clone --depth=1 --branch "$ref" "https://github.com/${owner}/${repo}.git" "$temp_dir" 2>/dev/null; then
    echo "  ⚠ Warning: Failed to clone ${owner}/${repo}@${ref}, skipping"
    rm -rf "$temp_dir"
    return 0
  fi

  local sha=$(cd "$temp_dir" && git rev-parse HEAD)

  # Create tar.gz with the action content (exclude .git)
  tar -czf "${action_dir}/${sha}.tar.gz" -C "$temp_dir" --exclude=.git .

  # Clean up
  rm -rf "$temp_dir"

  echo "  ✓ Cached ${owner}/${repo}@${ref} (SHA: ${sha:0:7})"
}

# Cache Docker actions (frequently timeout due to size)
cache_action docker build-push-action v5
cache_action docker build-push-action v6
cache_action docker login-action v2
cache_action docker login-action v3
cache_action docker metadata-action v4
cache_action docker metadata-action v5

# Cache GitHub official actions
cache_action actions checkout v3
cache_action actions checkout v4
cache_action actions setup-java v3
cache_action actions setup-java v4
cache_action actions upload-artifact v3
cache_action actions upload-artifact v4
cache_action actions download-artifact v3
cache_action actions download-artifact v4

# Cache third-party actions
cache_action dorny paths-filter v2
cache_action dorny paths-filter v3

# Set ownership to runner user
chown -R runner:runner "$CACHE_DIR"

echo ""
echo "✓ GitHub Actions cache complete"
echo "Cached in: $CACHE_DIR"
du -sh "$CACHE_DIR" 2>/dev/null || true
echo "Total cached actions: $(find "$CACHE_DIR" -name "*.tar.gz" 2>/dev/null | wc -l)"
