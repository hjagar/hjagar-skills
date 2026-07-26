#!/usr/bin/env bash
# us-refinement Auto-Updater for macOS and Linux
set -euo pipefail

CENTRAL_DIR="$HOME/.hjagar/skills/us-refinement"
LOCAL_SKILL="$CENTRAL_DIR/SKILL.md"
REPO="hjagar/us-refinement"

echo "Checking for updates..."

# 1. Read local version
if [ ! -f "$LOCAL_SKILL" ]; then
    echo "Error: us-refinement is not installed globally at $CENTRAL_DIR. Run install.sh first." >&2
    exit 1
fi

frontmatter=$(awk '/^---[[:space:]]*\r?$/{c++; if (c==2) {print buf; exit}; next} c==1 {buf = buf $0 ORS}' "$LOCAL_SKILL")
local_version=$(printf '%s\n' "$frontmatter" | grep -oE '^[[:space:]]*version:[[:space:]]*v[0-9.]+' | sed -E 's/^[[:space:]]*version:[[:space:]]*//' | head -n1 || true)
if [ -z "$local_version" ]; then
    local_version=$(grep -oE '<!-- version: v[0-9.]* -->' "$LOCAL_SKILL" | sed -E 's/<!-- version: (v[0-9.]*) -->/\1/' || true)
fi
[ -z "$local_version" ] && local_version="v0.0.0"
echo "Local version: $local_version"

# 2. Fetch latest remote version from GitHub
latest_version=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)

if [ -z "$latest_version" ]; then
    echo "Warning: Failed to fetch latest version info from GitHub API. Check connection." >&2
    exit 1
fi

echo "Latest remote version: $latest_version"

# 3. Compare versions
if [ "$local_version" = "$latest_version" ]; then
    echo "You are already on the latest version: $local_version"
    exit 0
fi

echo "New version $latest_version is available! Updating..."

# 4. Perform download and safe update
ZIP_URL="https://github.com/$REPO/releases/latest/download/us-refinement.zip"
TEMP_ZIP=$(mktemp --suffix=.zip 2>/dev/null || mktemp /tmp/us-refinement-XXXXXX.zip)
TEMP_EXTRACT_DIR=$(mktemp -d /tmp/us-refinement-extract-XXXXXX)

cleanup() {
    rm -f "$TEMP_ZIP"
    rm -rf "$TEMP_EXTRACT_DIR"
}
trap cleanup EXIT

echo "Downloading release archive..."
if ! curl -sSL -o "$TEMP_ZIP" "$ZIP_URL"; then
    echo "Error: Failed to download release ZIP from GitHub." >&2
    exit 1
fi

echo "Extracting archive..."
if ! unzip -o "$TEMP_ZIP" -d "$TEMP_EXTRACT_DIR" &>/dev/null; then
    echo "Error: Extraction failed." >&2
    exit 1
fi

# Validate the extracted archive is complete BEFORE clearing any existing central-store
# content below - update.sh now depends on lib/ to even finish (it sources
# lib/skill-payload.sh from the central store further down), so a truncated/incomplete
# archive must abort here instead of wiping a working install with no way back.
for required in SKILL.md scripts tests lib; do
    if [ ! -e "$TEMP_EXTRACT_DIR/$required" ]; then
        echo "Error: downloaded release archive is missing '$required' - aborting before touching the existing installation at $CENTRAL_DIR." >&2
        exit 1
    fi
done

echo "Updating central files..."
# Clear stale central-store dirs first: a plain merge-copy below would leave behind
# files removed/renamed in the new release, and those orphans would then be
# re-propagated to every agent path.
for dir in scripts tests lib; do
    rm -rf "${CENTRAL_DIR:?}/$dir"
done
cp -R "$TEMP_EXTRACT_DIR"/. "$CENTRAL_DIR/"

# build_agent_paths, copy_skill_file, and new_kiro_steering_file live in
# lib/skill-payload.sh (shared with install.sh). It was just refreshed into
# $CENTRAL_DIR above alongside scripts/ and tests/, so source the refreshed copy.
# shellcheck source=lib/skill-payload.sh
source "$CENTRAL_DIR/lib/skill-payload.sh"

# 5. Propagate SKILL.md + scripts/ + tests/ to all agents
echo "Updating agents..."
build_agent_paths

for agent in "${AGENT_PATHS[@]}"; do
    if [ -d "$agent" ] || [ -f "$agent" ]; then
        copy_skill_file "$agent" "$CENTRAL_DIR"
        echo "Updated agent skill path: $agent"
    fi
done

# Kiro is a special case: a single generated steering file at
# ~/.kiro/steering/us-refinement.md (SKILL.md's frontmatter with `inclusion: always`
# injected), not a folder+SKILL.md copy - no scripts/ or tests/ payload. Only
# regenerate it if it already exists - update.sh never opts a machine into a new agent,
# only refreshes agents already installed.
KIRO_TARGET="$HOME/.kiro/steering/us-refinement.md"
if [ -f "$KIRO_TARGET" ]; then
    new_kiro_steering_file "$CENTRAL_DIR"
    echo "Updated agent skill path: $KIRO_TARGET"
fi

echo "Update completed successfully to version $latest_version!"
