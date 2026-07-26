#!/usr/bin/env bash
set -e

LOCAL=false
SRC_DIR=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -l|--local) LOCAL=true ;;
        -p|--path) SRC_DIR="$2"; shift ;;
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
CENTRAL_DIR="$HOME/.hjagar/skills/us-refinement"

if [ -z "$SRC_DIR" ]; then
    SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 3. Installation Logic
# build_agent_paths, copy_skill_file, and new_kiro_steering_file live in
# lib/skill-payload.sh (shared with update.sh). Local mode sources it straight from
# $SRC_DIR - a real checkout, always present on disk. Global mode can only source it from
# $CENTRAL_DIR AFTER the release ZIP has been downloaded and extracted there below, since
# install.sh ships as a single self-contained file for the `curl <url> | bash`
# distribution path and has no sibling files available before that point.
if [ "$LOCAL" = true ]; then
    echo "Installing us-refinement in LOCAL Mode..."
    # shellcheck source=lib/skill-payload.sh
    source "$SRC_DIR/lib/skill-payload.sh"
    build_agent_paths
    for agent in "${AGENT_PATHS[@]}"; do
        copy_skill_file "$agent" "$SRC_DIR"
    done
    new_kiro_steering_file "$SRC_DIR"
else
    echo "Installing us-refinement in GLOBAL Mode..."
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

    # Only now does $CENTRAL_DIR physically contain lib/skill-payload.sh - source it from
    # there, never before the extraction above.
    # shellcheck source=lib/skill-payload.sh
    source "$CENTRAL_DIR/lib/skill-payload.sh"
    build_agent_paths
    for agent in "${AGENT_PATHS[@]}"; do
        copy_skill_file "$agent" "$CENTRAL_DIR"
    done
    new_kiro_steering_file "$CENTRAL_DIR"
fi

echo "Installation completed successfully!"
