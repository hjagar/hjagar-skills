#!/usr/bin/env bash
# hjagar-skills Auto-Updater for macOS and Linux
set -euo pipefail

SKILL_NAME=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skill) SKILL_NAME="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

CENTRAL_DIR="$HOME/.hjagar/skills"
REPO="hjagar/us-refinement"

echo "Checking for updates..."

# 1. Locate reference SKILL.md to check local version
CHECK_SKILL_FILE=""
if [ -n "$SKILL_NAME" ]; then
    if [ -f "$CENTRAL_DIR/skills/$SKILL_NAME/SKILL.md" ]; then
        CHECK_SKILL_FILE="$CENTRAL_DIR/skills/$SKILL_NAME/SKILL.md"
    elif [ -f "$CENTRAL_DIR/SKILL.md" ]; then
        CHECK_SKILL_FILE="$CENTRAL_DIR/SKILL.md"
    fi
else
    if [ -f "$CENTRAL_DIR/skills/us-refinement/SKILL.md" ]; then
        CHECK_SKILL_FILE="$CENTRAL_DIR/skills/us-refinement/SKILL.md"
    elif [ -f "$CENTRAL_DIR/SKILL.md" ]; then
        CHECK_SKILL_FILE="$CENTRAL_DIR/SKILL.md"
    fi
fi

if [ -z "$CHECK_SKILL_FILE" ] || [ ! -f "$CHECK_SKILL_FILE" ]; then
    echo "Error: skills are not installed globally at $CENTRAL_DIR. Run install.sh first." >&2
    exit 1
fi

frontmatter=$(awk '/^---[[:space:]]*\r?$/{c++; if (c==2) {print buf; exit}; next} c==1 {buf = buf $0 ORS}' "$CHECK_SKILL_FILE")
local_version=$(printf '%s\n' "$frontmatter" | grep -oE '^[[:space:]]*version:[[:space:]]*v[0-9.]+' | sed -E 's/^[[:space:]]*version:[[:space:]]*//' | head -n1 || true)
if [ -z "$local_version" ]; then
    local_version=$(grep -oE '<!-- version: v[0-9.]* -->' "$CHECK_SKILL_FILE" | sed -E 's/<!-- version: (v[0-9.]*) -->/\1/' || true)
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

echo "Updating central files..."
cp -R "$TEMP_EXTRACT_DIR"/. "$CENTRAL_DIR/"

PAYLOAD_LIB=""
if [ -f "$CENTRAL_DIR/lib/skill-payload.sh" ]; then
    PAYLOAD_LIB="$CENTRAL_DIR/lib/skill-payload.sh"
elif [ -f "$CENTRAL_DIR/cli/lib/skill-payload.sh" ]; then
    PAYLOAD_LIB="$CENTRAL_DIR/cli/lib/skill-payload.sh"
fi

if [ -n "$PAYLOAD_LIB" ]; then
    # shellcheck disable=SC1090,SC1091
    source "$PAYLOAD_LIB"
else
    echo "Error: lib/skill-payload.sh not found in central dir" >&2
    exit 1
fi

# 5. Propagate to agents
skills=()
if [ -n "$SKILL_NAME" ]; then
    skills+=("$SKILL_NAME")
else
    if [ -d "$CENTRAL_DIR/skills" ]; then
        for sdir in "$CENTRAL_DIR/skills"/*; do
            if [ -d "$sdir" ] && [ -f "$sdir/SKILL.md" ]; then
                skills+=("$(basename "$sdir")")
            fi
        done
    elif [ -f "$CENTRAL_DIR/SKILL.md" ]; then
        skills+=("$(basename "$CENTRAL_DIR")")
    fi
fi

for sk in "${skills[@]}"; do
    sk_src="$CENTRAL_DIR/skills/$sk"
    if [ ! -d "$sk_src" ] && [ -f "$CENTRAL_DIR/SKILL.md" ]; then
        sk_src="$CENTRAL_DIR"
    fi

    echo "Updating agent paths for skill '$sk'..."
    build_agent_paths "$sk"
    for agent in "${AGENT_PATHS[@]}"; do
        if [ -d "$agent" ] || [ -f "$agent" ]; then
            copy_skill_file "$agent" "$sk_src"
            echo "Updated agent skill path: $agent"
        fi
    done

    KIRO_TARGET="$HOME/.kiro/steering/$sk.md"
    if [ -f "$KIRO_TARGET" ]; then
        new_kiro_steering_file "$sk_src" "$sk"
        echo "Updated agent skill path: $KIRO_TARGET"
    fi
done

echo "Update completed successfully to version $latest_version!"
