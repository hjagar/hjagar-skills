#!/usr/bin/env bash
set -euo pipefail

echo "=== hjagar-skills Uninstaller ==="

SKILL_NAME=""
UNINSTALL_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill)
            SKILL_NAME="${2:-}"
            shift 2
            ;;
        --all)
            UNINSTALL_ALL=true
            shift
            ;;
        *)
            if [[ -z "$SKILL_NAME" ]]; then
                SKILL_NAME="$1"
            fi
            shift
            ;;
    esac
done

if [[ "$UNINSTALL_ALL" == false && -z "$SKILL_NAME" ]]; then
    echo "Options:"
    echo "  1) Uninstall a specific skill"
    echo "  2) Uninstall ALL skills"
    read -rp "Select option (1/2): " choice
    if [[ "$choice" == "2" ]]; then
        UNINSTALL_ALL=true
    else
        read -rp "Enter skill name to uninstall: " SKILL_NAME
    fi
fi

read -r -p "Proceed with uninstallation? (y/N) " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CENTRAL_BASE="$HOME/.hjagar/skills"

if [[ -f "$SCRIPT_DIR/lib/skill-payload.sh" ]]; then
    # shellcheck source=cli/lib/skill-payload.sh
    source "$SCRIPT_DIR/lib/skill-payload.sh"
else
    build_agent_paths() {
        local skill="$1"
        AGENT_PATHS=(
            "$HOME/.gemini/skills/$skill"
            "$HOME/.claude/skills/$skill"
            "$HOME/.config/opencode/skills/$skill"
            "$HOME/.copilot/skills/$skill"
            "$HOME/.agents/skills/$skill"
            "$HOME/.cursor/skills/$skill"
        )
        for d in "$HOME"/.claude-*; do
            if [ -d "$d" ]; then
                AGENT_PATHS+=("$d/skills/$skill")
            fi
        done
    }
fi

uninstall_single_skill() {
    local skill="$1"
    echo "Uninstalling skill: $skill..."

    build_agent_paths "$skill"
    for agent_dir in "${AGENT_PATHS[@]}"; do
        if [ -L "$agent_dir" ] || [ -e "$agent_dir" ]; then
            rm -rf "$agent_dir"
            echo "  Removed agent link/dir: $agent_dir"
        fi
    done

    local kiro_file="$HOME/.kiro/steering/$skill.md"
    if [ -f "$kiro_file" ]; then
        rm -f "$kiro_file"
        echo "  Removed Kiro steering file: $kiro_file"
    fi

    local central_skill_dir="$CENTRAL_BASE/$skill"
    if [ -d "$central_skill_dir" ]; then
        rm -rf "$central_skill_dir"
        echo "  Removed central skill directory: $central_skill_dir"
    fi
}

if [[ "$UNINSTALL_ALL" == true ]]; then
    echo "Uninstalling all skills..."
    if [ -d "$CENTRAL_BASE" ]; then
        for d in "$CENTRAL_BASE"/*/; do
            if [ -d "$d" ]; then
                skill_name=$(basename "$d")
                uninstall_single_skill "$skill_name"
            fi
        done
        rm -rf "$CENTRAL_BASE"
        echo "Cleaned central storage: $CENTRAL_BASE"
    fi

    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/skills" ]; then
        for s in "$REPO_ROOT/skills"/*/; do
            if [ -d "$s" ]; then
                skill_name=$(basename "$s")
                uninstall_single_skill "$skill_name"
            fi
        done
    fi
else
    uninstall_single_skill "$SKILL_NAME"
fi

echo "Uninstallation completed successfully."
