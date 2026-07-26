#!/usr/bin/env bash
# lib/skill-payload.sh
# Canonical Bash implementations shared by install.sh and update.sh:
#   - build_agent_paths     : populates the AGENT_PATHS array (static entries + dynamic
#                             .claude-* multi-account discovery)
#   - copy_skill_file       : SKILL.md + scripts/ + tests/ staged copy/swap
#   - new_kiro_steering_file: Kiro steering-file frontmatter-injection transform
#
# This file is meant to be sourced, not executed directly - it only defines functions
# and sets no options of its own (the sourcing script's `set -e`/`set -euo pipefail`
# context applies unchanged). `source`/`.` runs this file's statements directly in the
# calling shell, so functions defined here become ordinary functions in the caller's own
# shell - build_agent_paths relies on that to populate the caller's AGENT_PATHS array
# (bash has no clean way to "return" an array, so it is treated as a global by
# convention, same as the pre-unification inline code did), and new_kiro_steering_file
# relies on $HOME, which is already a normal exported environment variable visible
# everywhere with no scoping concerns.
#
# Distribution timing (see CLAUDE.md "Installers" section for the full constraint):
# install.sh sources this file from $SRC_DIR in local mode (a real checkout, always
# available on disk) or from $CENTRAL_DIR in global mode - but only AFTER the release ZIP
# has been downloaded and extracted there. install.sh itself ships as a single
# self-contained file for the `curl <url> | bash` distribution path and cannot source
# anything before that extraction happens, since no sibling files exist yet at that
# point. update.sh always runs from a real central-store checkout; it refreshes this file
# from the newly-downloaded release ZIP alongside scripts/ and tests/, then sources the
# refreshed copy.

# Builds the AGENT_PATHS array (static entries + dynamic .claude-* multi-account
# discovery). Requires $HOME to be set, which it always is.
build_agent_paths() {
    AGENT_PATHS=(
        "$HOME/.gemini/skills/us-refinement"
        "$HOME/.claude/skills/us-refinement"
        "$HOME/.config/opencode/skills/us-refinement"
        "$HOME/.copilot/skills/us-refinement"
        "$HOME/.agents/skills/us-refinement"
        "$HOME/.cursor/skills/us-refinement"
    )

    for d in "$HOME"/.claude-*; do
        if [ -d "$d" ]; then
            AGENT_PATHS+=("$d/skills/us-refinement")
        fi
    done
}

# Payload Copy Helper (SKILL.md + scripts/ + tests/ - docs/ excluded on purpose)
# Stages the payload in a sibling ".staging" dir and swaps it into place only after every
# copy succeeds, so a mid-copy failure (caught by `set -e`) leaves the existing installed
# payload untouched.
copy_skill_file() {
    local target="$1"
    local source="$2"
    local staging="${target}.staging"

    mkdir -p "$(dirname "$target")"
    rm -rf "$staging"
    mkdir -p "$staging"

    if [ -f "$source/SKILL.md" ]; then
        echo "Copying SKILL.md to: $target"
        cp "$source/SKILL.md" "$staging/"
    else
        echo "Error: SKILL.md not found at $source" >&2
        rm -rf "$staging"
        exit 1
    fi

    for dir in scripts tests assets references; do
        if [ -d "$source/$dir" ]; then
            echo "Copying $dir/ to: $target"
            cp -r "$source/$dir" "$staging/"
        else
            echo "Warning: $dir/ not found at $source - skipping." >&2
        fi
    done

    rm -rf "$target"
    mv "$staging" "$target"
}

# Kiro Steering File Helper
# Kiro does not use the folder+SKILL.md format other agents use: it reads a single flat
# steering file at ~/.kiro/steering/us-refinement.md with `inclusion: always` injected as
# the first key inside SKILL.md's YAML frontmatter. No scripts/ or tests/ payload - steering
# files are plain markdown only. Stages then swaps into place for the same atomicity
# guarantee as copy_skill_file.
new_kiro_steering_file() {
    local source="$1"
    local steering_dir="$HOME/.kiro/steering"
    local target="$steering_dir/us-refinement.md"
    local staging="${target}.staging"
    local src_file="$source/SKILL.md"

    if [ ! -f "$src_file" ]; then
        echo "Error: SKILL.md not found at $source" >&2
        exit 1
    fi

    # Checked via a pipe (never captured into a shell variable) so a CRLF-terminated
    # source line's trailing \r survives intact for the comparison below.
    if ! sed -n '1p' "$src_file" | grep -Eq $'^---\r?$'; then
        echo "Error: SKILL.md at $source does not start with a '---' YAML frontmatter delimiter - cannot generate Kiro steering file." >&2
        exit 1
    fi

    mkdir -p "$steering_dir"
    echo "Generating Kiro steering file: $target"

    # Match the injected line's terminator to the source file's own EOL style (CRLF vs LF),
    # detected from line 1, so the output doesn't end up with mixed line endings.
    local injected_line="inclusion: always"$'\n'
    if sed -n '1p' "$src_file" | grep -q $'\r$'; then
        injected_line="inclusion: always"$'\r\n'
    fi

    # Insert `inclusion: always` as a new line right after the opening `---` delimiter.
    # Every other line is streamed straight through via sed (never captured into a shell
    # variable), so it reaches the output byte-for-byte regardless of its EOL style.
    {
        sed -n '1p' "$src_file"
        printf '%s' "$injected_line"
        sed -n '2,$p' "$src_file"
    } > "$staging"

    rm -f "$target"
    mv "$staging" "$target"
}
