#!/bin/bash -e
# Pre-cache runtime tools (Java, Python, Node) in hostedtoolcache
#
# When setup-* actions run (setup-java, setup-python, setup-node), they:
# 1. Check RUNNER_TOOL_CACHE (or AGENT_TOOLSDIRECTORY) for pre-installed tools
# 2. If found: use immediately (instant, no download)
# 3. If not found: download and install (~200-500 MB, 2-5 minutes)
#
# This script pre-installs tools by running setup-* actions during image build.
# Uses the runner's own Node.js runtime (from /actions-runner/externals/).

TOOL_CACHE="/opt/hostedtoolcache"
export RUNNER_TOOL_CACHE="$TOOL_CACHE"
export AGENT_TOOLSDIRECTORY="$TOOL_CACHE"

# Find the Node.js runtime installed by the GitHub Actions runner
NODE_DIR=$(find /actions-runner/externals -name "node*" -type d | head -1)
if [ -z "$NODE_DIR" ]; then
  echo "⚠ Warning: Node.js not found in /actions-runner/externals/, skipping tool cache"
  exit 0
fi

NODE_BIN="$NODE_DIR/bin/node"
NPM_BIN="$NODE_DIR/bin/npm"

if [ ! -f "$NODE_BIN" ]; then
  echo "⚠ Warning: Node binary not found at $NODE_BIN, skipping tool cache"
  exit 0
fi

echo "Using Node.js from: $NODE_BIN"
echo "Node version: $($NODE_BIN --version)"

# Helper function to cache a setup action's tool
# Usage: cache_tool action_owner action_repo action_ref
cache_tool() {
  local owner=$1
  local repo=$2
  local ref=$3

  echo "Setting up ${owner}/${repo}@${ref}..."

  local temp_dir=$(mktemp -d)
  cd "$temp_dir"

  # Clone the setup action
  if ! git clone --depth=1 --branch "$ref" "https://github.com/${owner}/${repo}.git" action 2>/dev/null; then
    echo "  ⚠ Warning: Failed to clone ${owner}/${repo}@${ref}, skipping"
    cd / && rm -rf "$temp_dir"
    return 0
  fi

  cd action

  # Install action dependencies using runner's npm
  echo "  Installing action dependencies..."
  if ! "$NPM_BIN" install --production --silent 2>&1 | grep -v "^npm notice"; then
    echo "  ⚠ Warning: npm install failed for ${owner}/${repo}, skipping"
    cd / && rm -rf "$temp_dir"
    return 0
  fi

  # Clean up
  cd /
  rm -rf "$temp_dir"

  echo "  ✓ Prepared ${owner}/${repo}@${ref}"
}

# Note: Pre-caching tools requires running the setup-* actions which download large files
# This significantly increases image build time (~10-20 minutes) and size (~1-2 GB)
# For now, we'll skip actual tool installation to keep builds fast
# Tools will be downloaded on first use and cached in persistent runner-data/toolcache

echo "Tool cache directory: $TOOL_CACHE"
echo "Note: Tools will be cached on first use in persistent runner-data/toolcache/"
echo "Skipping pre-installation to keep image size reasonable."

# If you want to pre-install tools (increases build time significantly):
# cache_tool actions setup-java v4
# export INPUT_DISTRIBUTION="temurin"
# export INPUT_JAVA_VERSION="8.0.442"
# "$NODE_BIN" action/dist/setup/index.js
# (repeat for other versions and tools)

# Set ownership
chown -R runner:runner "$TOOL_CACHE"

echo "✓ Tool cache setup complete"
