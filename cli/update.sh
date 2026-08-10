#!/usr/bin/env bash
# hjagar-skills Auto-Updater for macOS and Linux
set -euo pipefail

# Monorepo release source (US-17). All releases for every skill are published as
# `<skill>-v*` tags against this single repo — never a per-skill mirror.
REPO="hjagar/hjagar-skills"
CENTRAL_DIR="$HOME/.hjagar/skills"

# ---------------------------------------------------------------------------
# Pure / testable helper functions (identical contract to install.sh)
# ---------------------------------------------------------------------------

validate_skill_name() {
    local raw="$1"
    if [[ "$raw" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        return 0
    fi
    echo "Error: invalid skill name '$raw'." >&2
    return 1
}

select_highest_tag() {
    local skill="$1"
    local tags="$2"
    local prefix="${skill}-v"
    local matched
    matched="$(printf '%s\n' "$tags" | grep -E "^${prefix}[0-9]" || true)"
    if [ -z "$matched" ]; then
        return 0
    fi
    printf '%s\n' "$matched" \
        | sed -E "s/^${prefix}//" \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -n1 \
        | sed -E "s/^/${prefix}/"
}

fetch_release_tags() {
    local repo="$1"
    local raw=""

    if command -v gh &>/dev/null; then
        raw="$(gh api --paginate "repos/${repo}/releases" --jq '.[].tag_name' 2>/dev/null)"
        if [ -n "$raw" ]; then
            printf '%s\n' "$raw"
            return 0
        fi
    fi

    if command -v curl &>/dev/null; then
        raw="$(curl -sSL "https://api.github.com/repos/${repo}/releases" 2>/dev/null)"
        if [ -n "$raw" ]; then
            printf '%s\n' "$raw" \
                | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
                | sed -E 's/.*"([^"]+)"$/\1/'
            return 0
        fi
    fi

    if command -v wget &>/dev/null; then
        raw="$(wget -qO- "https://api.github.com/repos/${repo}/releases" 2>/dev/null)"
        if [ -n "$raw" ]; then
            printf '%s\n' "$raw" \
                | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
                | sed -E 's/.*"([^"]+)"$/\1/'
            return 0
        fi
    fi

    return 1
}

resolve_release_tag() {
    local repo="$1"
    local skill="$2"
    local tags
    tags="$(fetch_release_tags "$repo")" || return 1
    select_highest_tag "$skill" "$tags"
}

# Filesystem-only (US-17 D8): lists the skill names already installed under
# $CENTRAL_DIR/skills/*, one per line. Never touches the network — safe to
# unit test against a scratch CENTRAL_DIR. This is what an omitted --skill
# updates (every LOCALLY installed skill, each via its own resolved tag) —
# never a hardcoded default skill.
discover_locally_installed_skills() {
    if [ -d "$CENTRAL_DIR/skills" ]; then
        for sdir in "$CENTRAL_DIR/skills"/*; do
            if [ -d "$sdir" ] && [ -f "$sdir/SKILL.md" ]; then
                basename "$sdir"
            fi
        done
    elif [ -f "$CENTRAL_DIR/SKILL.md" ]; then
        # Legacy flat central install (no skills/<name>/ subfolder) — same
        # limitation as pre-US-17 update.sh: the actual skill name isn't
        # recoverable from a flat layout, so this falls back to the central
        # dir's own basename.
        basename "$CENTRAL_DIR"
    fi
}

print_no_release_error() {
    local skill="$1"
    echo "Error: no released version found for skill '${skill}' in ${REPO}." >&2
    echo "Install from a local checkout instead: install.sh -l -p <path>  /  install.ps1 -Local -Path <path>" >&2
}

download_release_zip() {
    local repo="$1" tag="$2" skill="$3" out_zip="$4"

    if command -v gh &>/dev/null; then
        if gh release download "$tag" --repo "$repo" --pattern "${skill}.zip" --output "$out_zip" --clobber &>/dev/null; then
            return 0
        fi
    fi

    local url="https://github.com/${repo}/releases/download/${tag}/${skill}.zip"
    if command -v curl &>/dev/null; then
        if curl -sSL -o "$out_zip" "$url" &>/dev/null; then
            return 0
        fi
    elif command -v wget &>/dev/null; then
        if wget -q -O "$out_zip" "$url"; then
            return 0
        fi
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Local-version detection (unchanged logic, extracted into a function so it
# can run as an approval test without triggering any network/copy side
# effects).
# ---------------------------------------------------------------------------

detect_local_version() {
    # Always called with a concrete skill name (update_one_skill's single
    # caller, whether from --skill or the discover-locally-installed loop,
    # US-17 D8) — no empty-name/default-skill branch needed anymore.
    local skill_name="$1"
    local check_skill_file=""

    if [ -f "$CENTRAL_DIR/skills/$skill_name/SKILL.md" ]; then
        check_skill_file="$CENTRAL_DIR/skills/$skill_name/SKILL.md"
    elif [ -f "$CENTRAL_DIR/SKILL.md" ]; then
        check_skill_file="$CENTRAL_DIR/SKILL.md"
    fi

    if [ -z "$check_skill_file" ] || [ ! -f "$check_skill_file" ]; then
        return 1
    fi

    local frontmatter local_version
    frontmatter=$(awk '/^---[[:space:]]*\r?$/{c++; if (c==2) {print buf; exit}; next} c==1 {buf = buf $0 ORS}' "$check_skill_file")
    local_version=$(printf '%s\n' "$frontmatter" | grep -oE '^[[:space:]]*version:[[:space:]]*v[0-9.]+' | sed -E 's/^[[:space:]]*version:[[:space:]]*//' | head -n1 || true)
    if [ -z "$local_version" ]; then
        local_version=$(grep -oE '<!-- version: v[0-9.]* -->' "$check_skill_file" | sed -E 's/<!-- version: (v[0-9.]*) -->/\1/' || true)
    fi
    [ -z "$local_version" ] && local_version="v0.0.0"
    printf '%s\n' "$local_version"
}

# ---------------------------------------------------------------------------
# update_one_skill — resolves, compares, downloads, and propagates the
# update for ONE skill. Used both for `--skill <name>` (single invocation)
# and the discover-locally-installed loop (US-17 D8, one invocation per
# already-installed skill, since each has its own independently-tagged
# release). Exits 1 on any resolution/download/extraction failure; returns 0
# (without downloading) when already on the latest version.
# ---------------------------------------------------------------------------

update_one_skill() {
    local skill="$1"

    # 1. Locate reference SKILL.md to check local version
    local local_version
    local_version="$(detect_local_version "$skill")" || {
        echo "Error: skills are not installed globally at $CENTRAL_DIR. Run install.sh first." >&2
        exit 1
    }
    echo "Local version: $local_version"

    # 2. Resolve latest matching `<skill>-v*` tag from the monorepo
    echo "Resolving release for skill '$skill' in $REPO..."
    local resolve_status=0
    local tag
    tag="$(resolve_release_tag "$REPO" "$skill")" || resolve_status=$?
    if [ "$resolve_status" -ne 0 ]; then
        echo "Warning: Failed to fetch latest version info from GitHub API. Check connection." >&2
        exit 1
    fi
    if [ -z "$tag" ]; then
        print_no_release_error "$skill"
        exit 1
    fi

    local latest_version="${tag#"${skill}"-}"
    echo "Latest remote version: $latest_version"

    # 3. Compare versions
    if [ "$local_version" = "$latest_version" ]; then
        echo "You are already on the latest version: $local_version"
        return 0
    fi

    echo "New version $latest_version is available! Updating..."

    # 4. Perform download and safe update. TEMP_ZIP/TEMP_EXTRACT_DIR are
    # intentionally globals (not `local`) so the single `cleanup` trap
    # registered once in main() always cleans up whichever skill's temp
    # files are currently in flight, including on a `set -e`-triggered
    # abrupt exit mid-loop.
    TEMP_ZIP=$(mktemp --suffix=.zip 2>/dev/null || mktemp "/tmp/${skill}-XXXXXX.zip")
    TEMP_EXTRACT_DIR=$(mktemp -d "/tmp/${skill}-extract-XXXXXX")

    echo "Downloading release archive..."
    if ! download_release_zip "$REPO" "$tag" "$skill" "$TEMP_ZIP"; then
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

    local payload_lib=""
    if [ -f "$CENTRAL_DIR/lib/skill-payload.sh" ]; then
        payload_lib="$CENTRAL_DIR/lib/skill-payload.sh"
    elif [ -f "$CENTRAL_DIR/cli/lib/skill-payload.sh" ]; then
        payload_lib="$CENTRAL_DIR/cli/lib/skill-payload.sh"
    fi

    if [ -n "$payload_lib" ]; then
        # shellcheck disable=SC1090,SC1091
        source "$payload_lib"
    else
        echo "Error: lib/skill-payload.sh not found in central dir" >&2
        exit 1
    fi

    # 5. Propagate to agents
    local sk_src="$CENTRAL_DIR/skills/$skill"
    if [ ! -d "$sk_src" ] && [ -f "$CENTRAL_DIR/SKILL.md" ]; then
        sk_src="$CENTRAL_DIR"
    fi

    echo "Updating agent paths for skill '$skill'..."
    build_agent_paths "$skill"
    for agent in "${AGENT_PATHS[@]}"; do
        if [ -d "$agent" ] || [ -f "$agent" ]; then
            copy_skill_file "$agent" "$sk_src"
            echo "Updated agent skill path: $agent"
        fi
    done

    local kiro_target="$HOME/.kiro/steering/$skill.md"
    if [ -f "$kiro_target" ]; then
        new_kiro_steering_file "$sk_src" "$skill"
        echo "Updated agent skill path: $kiro_target"
    fi

    echo "Update completed successfully to version $latest_version!"

    rm -f "$TEMP_ZIP"
    rm -rf "$TEMP_EXTRACT_DIR"
    TEMP_ZIP=""
    TEMP_EXTRACT_DIR=""
}

# ---------------------------------------------------------------------------
# main — guarded so this file can be sourced (for unit tests) without running
# any update side effects.
# ---------------------------------------------------------------------------

main() {
    SKILL_NAME=""

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --skill) SKILL_NAME="$2"; shift ;;
            *) echo "Unknown parameter: $1"; exit 1 ;;
        esac
        shift
    done

    # Skill-name validation — BEFORE any interpolation into a URL, jq filter,
    # regex, or filesystem path.
    if [ -n "$SKILL_NAME" ]; then
        validate_skill_name "$SKILL_NAME" || exit 1
    fi

    TEMP_ZIP=""
    TEMP_EXTRACT_DIR=""
    cleanup() {
        # `[ -n "$X" ] && rm ...` would return 1 (and, under `set -e`, corrupt
        # this trap's — and therefore the whole script's — exit status) when
        # X is already empty, which is the common case once update_one_skill
        # has already cleaned up after itself. `if`/`fi` always returns 0.
        if [ -n "$TEMP_ZIP" ]; then rm -f "$TEMP_ZIP"; fi
        if [ -n "$TEMP_EXTRACT_DIR" ]; then rm -rf "$TEMP_EXTRACT_DIR"; fi
        return 0
    }
    trap cleanup EXIT

    echo "Checking for updates..."

    if [ -n "$SKILL_NAME" ]; then
        update_one_skill "$SKILL_NAME"
    else
        # US-17 D8: no --skill given -> update EVERY skill already found
        # locally under $CENTRAL_DIR/skills/*, each via its own resolved
        # tag. Never defaults to a single hardcoded skill (D5 superseded).
        SKILLS_TO_UPDATE=()
        while IFS= read -r local_skill; do
            [ -n "$local_skill" ] && SKILLS_TO_UPDATE+=("$local_skill")
        done <<< "$(discover_locally_installed_skills)"

        if [ ${#SKILLS_TO_UPDATE[@]} -eq 0 ]; then
            echo "Error: skills are not installed globally at $CENTRAL_DIR. Run install.sh first." >&2
            exit 1
        fi

        for sk in "${SKILLS_TO_UPDATE[@]}"; do
            update_one_skill "$sk"
        done
    fi
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
