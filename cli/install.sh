#!/usr/bin/env bash
set -e

LOCAL=false
SRC_DIR=""
SKILL_NAME=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -l|--local) LOCAL=true ;;
        -p|--path) SRC_DIR="$2"; shift ;;
        --skill) SKILL_NAME="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# 1. Prerequisites Check
echo "Checking prerequisites..."
if ! command -v git &> /dev/null; then
    echo "Error: git is required to use this skill."
    exit 1
fi
if ! command -v gh &> /dev/null; then
    echo "Warning: gh CLI was not found. Issue refinement write-backs will fallback to copy/paste."
fi

# 2. Path Setup
CENTRAL_DIR="$HOME/.hjagar/skills"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$SRC_DIR" ]; then
    if [ -d "$SCRIPT_DIR/../skills" ]; then
        BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    else
        BASE_DIR="$SCRIPT_DIR"
    fi
else
    BASE_DIR="$SRC_DIR"
fi

install_skills() {
    local payload_src="$1"
    local base_src="$2"

    if [ -f "$payload_src/lib/skill-payload.sh" ]; then
        source "$payload_src/lib/skill-payload.sh"
    elif [ -f "$payload_src/cli/lib/skill-payload.sh" ]; then
        source "$payload_src/cli/lib/skill-payload.sh"
    else
        echo "Error: lib/skill-payload.sh not found at $payload_src" >&2
        exit 1
    fi

    local skills=()
    if [ -n "$SKILL_NAME" ]; then
        if [ -d "$base_src/skills/$SKILL_NAME" ] && [ -f "$base_src/skills/$SKILL_NAME/SKILL.md" ]; then
            skills+=("$SKILL_NAME")
        elif [ -f "$base_src/SKILL.md" ]; then
            skills+=("$(basename "$base_src")")
        else
            echo "Error: Skill '$SKILL_NAME' not found in $base_src" >&2
            exit 1
        fi
    else
        if [ -d "$base_src/skills" ]; then
            for sdir in "$base_src/skills"/*; do
                if [ -d "$sdir" ] && [ -f "$sdir/SKILL.md" ]; then
                    skills+=("$(basename "$sdir")")
                fi
            done
        elif [ -f "$base_src/SKILL.md" ]; then
            skills+=("$(basename "$base_src")")
        fi
    fi

    if [ ${#skills[@]} -eq 0 ]; then
        echo "Error: No valid skills found to install." >&2
        exit 1
    fi

    for sk in "${skills[@]}"; do
        local sk_dir="$base_src/skills/$sk"
        if [ ! -d "$sk_dir" ] && [ -f "$base_src/SKILL.md" ]; then
            sk_dir="$base_src"
        fi

        echo "Installing skill '$sk'..."
        build_agent_paths "$sk"
        for agent in "${AGENT_PATHS[@]}"; do
            copy_skill_file "$agent" "$sk_dir"
        done
        new_kiro_steering_file "$sk_dir" "$sk"
    done
}

# 3. Installation Logic
if [ "$LOCAL" = true ]; then
    echo "Installing in LOCAL Mode..."
    install_skills "$BASE_DIR" "$BASE_DIR"
else
    echo "Installing in GLOBAL Mode..."
    rm -rf "$CENTRAL_DIR"
    mkdir -p "$CENTRAL_DIR"
    
    ZIP_URL="https://github.com/hjagar/us-refinement/releases/latest/download/us-refinement.zip"
    TEMP_ZIP=$(mktemp --suffix=.zip 2>/dev/null || mktemp /tmp/us-refinement-XXXXXX.zip)
    
    DOWNLOAD_SUCCESS=false
    
    # Try downloading via gh CLI first (useful for private repos)
    if command -v gh &>/dev/null; then
        echo "Downloading latest release ZIP using GitHub CLI..."
        if gh release download --repo hjagar/us-refinement --pattern "us-refinement.zip" --output "$TEMP_ZIP" --clobber &>/dev/null; then
            DOWNLOAD_SUCCESS=true
        fi
    fi
    
    # Fallback to curl or wget
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo "Downloading latest release ZIP from public GitHub URL..."
        if command -v curl &>/dev/null; then
            if curl -sSL -o "$TEMP_ZIP" "$ZIP_URL"; then
                DOWNLOAD_SUCCESS=true
            fi
        elif command -v wget &>/dev/null; then
            if wget -q -O "$TEMP_ZIP" "$ZIP_URL"; then
                DOWNLOAD_SUCCESS=true
            fi
        fi
    fi
    
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo "Error: Failed to download release ZIP. Ensure gh CLI is authenticated or curl/wget is installed and has internet access." >&2
        rm -f "$TEMP_ZIP"
        exit 1
    fi
    
    echo "Extracting release ZIP..."
    if ! command -v unzip &>/dev/null; then
        echo "Error: unzip is required but was not found." >&2
        rm -f "$TEMP_ZIP"
        exit 1
    fi
    if ! unzip -o "$TEMP_ZIP" -d "$CENTRAL_DIR" &>/dev/null; then
        echo "Error: extraction failed." >&2
        rm -rf "$CENTRAL_DIR"
        rm -f "$TEMP_ZIP"
        exit 1
    fi
    rm -f "$TEMP_ZIP"

    install_skills "$CENTRAL_DIR" "$CENTRAL_DIR"
fi

echo "Installation completed successfully!"
