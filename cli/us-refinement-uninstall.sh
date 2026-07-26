#!/usr/bin/env bash
set -euo pipefail

read -r -p "Remove us-refinement? This will delete files and remove agent configurations. (y/N) " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

CENTRAL_DIR="$HOME/.hjagar/skills/us-refinement"
AGENT_PATHS=(
    "$HOME/.gemini/skills/us-refinement"
    "$HOME/.claude/skills/us-refinement"
    "$HOME/.config/opencode/skills/us-refinement"
    "$HOME/.copilot/skills/us-refinement"
    "$HOME/.agents/skills/us-refinement"
    "$HOME/.cursor/skills/us-refinement"
)

# Dynamic multi-account .claude-* detection
for d in "$HOME"/.claude-*; do
    if [ -d "$d" ]; then
        AGENT_PATHS+=("$d/skills/us-refinement")
    fi
done

# Remove agent paths
for agent in "${AGENT_PATHS[@]}"; do
    if [ -L "$agent" ] || [ -e "$agent" ]; then
        rm -rf "$agent"
        echo "Removed agent link: $agent"
    fi
done

# Kiro is a special case: a single generated steering file, not a folder - remove only that
# file, never the parent ~/.kiro/steering/ directory (other unrelated Kiro skills may live there).
KIRO_STEERING_FILE="$HOME/.kiro/steering/us-refinement.md"
if [ -f "$KIRO_STEERING_FILE" ]; then
    rm -f "$KIRO_STEERING_FILE"
    echo "Removed: $KIRO_STEERING_FILE"
fi

# Determine script execution context
SELF="${BASH_SOURCE[0]}"
EXEC_DIR=$(cd "$(dirname "$SELF")" && pwd)
CENTRAL_DIR_ABS=$(cd "$HOME/.hjagar/skills/us-refinement" 2>/dev/null && pwd || echo "$HOME/.hjagar/skills/us-refinement")

if [ "$EXEC_DIR" = "$CENTRAL_DIR_ABS" ]; then
    # Running from central directory. Delete files, leaving the running script for last.
    find "$CENTRAL_DIR_ABS" -mindepth 1 -not -path "$SELF" -delete 2>/dev/null || true
    echo "Central files cleaned up."
else
    if [ -d "$CENTRAL_DIR" ]; then
        rm -rf "$CENTRAL_DIR"
        echo "Removed central directory: $CENTRAL_DIR"
    fi
fi

# Clean parent directories if empty
SKILLS_DIR=$(dirname "$CENTRAL_DIR")
if [ -d "$SKILLS_DIR" ] && [ -z "$(ls -A "$SKILLS_DIR" 2>/dev/null)" ]; then
    rmdir "$SKILLS_DIR"
    echo "Removed empty parent: $SKILLS_DIR"
fi
HJAGAR_DIR=$(dirname "$SKILLS_DIR")
if [ -d "$HJAGAR_DIR" ] && [ -z "$(ls -A "$HJAGAR_DIR" 2>/dev/null)" ]; then
    rmdir "$HJAGAR_DIR"
    echo "Removed empty parent: $HJAGAR_DIR"
fi

# Self-deletion if running from central directory
if [ "$EXEC_DIR" = "$CENTRAL_DIR_ABS" ]; then
    [ -e "$SELF" ] && rm -f -- "$SELF"
else
    echo "Running from clone - remove us-refinement-uninstall.sh manually if needed."
fi

echo "Uninstallation completed successfully."
