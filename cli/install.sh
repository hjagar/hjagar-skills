#!/usr/bin/env bash
set -e

# Monorepo release source (US-17). All releases for every skill are published as
# `<skill>-v*` tags against this single repo — never a per-skill mirror.
REPO="hjagar/hjagar-skills"

# ---------------------------------------------------------------------------
# Pure / testable helper functions
# ---------------------------------------------------------------------------

# Validates a skill name BEFORE it is interpolated into any URL, jq filter,
# regex, or filesystem path. Prints an error to stderr and returns 1 when the
# name doesn't match ^[a-z0-9][a-z0-9-]*$.
validate_skill_name() {
    local raw="$1"
    if [[ "$raw" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        return 0
    fi
    echo "Error: invalid skill name '$raw'." >&2
    return 1
}

# Pure: given a skill name and a newline-separated list of tag names, prints
# the highest matching `<skill>-v*` tag using 2-digit-safe semver ordering
# (v1.10.0 > v1.9.0), or prints nothing if no tag matches. Never touches the
# network — safe to unit test with canned fixtures.
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

# Network: lists release tag_names for $1=repo via `gh` (preferred, works for
# private repos when authenticated) or curl/wget (unauthenticated fallback).
# Prints one tag per line. Returns 1 only when no tool could list releases at
# all (infrastructure failure) — an empty-but-successful list is NOT a failure.
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

# Resolves the exact release tag for $2=skill against $1=repo. Prints the tag
# (or nothing, if the list was fetched successfully but nothing matched) and
# returns 0, OR returns 1 with no output when tags could not be listed at all.
resolve_release_tag() {
    local repo="$1"
    local skill="$2"
    local tags
    tags="$(fetch_release_tags "$repo")" || return 1
    select_highest_tag "$skill" "$tags"
}

# Pure (US-17 D8): given a newline-separated list of tag names, extracts the
# distinct skill names by matching the exact `<skill>-vMAJOR.MINOR.PATCH`
# shape and stripping the trailing version suffix. Deduped and sorted for a
# deterministic install order. Never touches the network — safe to unit test.
extract_skill_names_from_tags() {
    local tags="$1"
    printf '%s\n' "$tags" \
        | grep -E '^[a-z0-9][a-z0-9-]*-v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sed -E 's/-v[0-9]+\.[0-9]+\.[0-9]+$//' \
        | sort -u
}

# Network (US-17 D8): discovers every distinct skill name that has at least
# one `<skill>-v*` release in $1=repo, by reusing the exact same
# fetch_release_tags call already used for single-skill resolution. Prints
# one name per line and returns 0 (possibly empty output, if the repo has
# releases but none matching the tag shape), OR returns 1 with no output when
# the release list itself could not be fetched at all.
discover_all_skill_names() {
    local repo="$1"
    local tags
    tags="$(fetch_release_tags "$repo")" || return 1
    extract_skill_names_from_tags "$tags"
}

# Identical error text is required across install.sh/install.ps1/update.sh/update.ps1.
print_no_release_error() {
    local skill="$1"
    echo "Error: no released version found for skill '${skill}' in ${REPO}." >&2
    echo "Install from a local checkout instead: install.sh -l -p <path>  /  install.ps1 -Local -Path <path>" >&2
}

# Downloads the exact tag's `<skill>.zip` via `gh release download` (preferred)
# or a tag-scoped curl/wget URL (unauthenticated fallback, no server-side tag
# glob exists — the tag must already be resolved to an exact value).
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
# install_one_skill_global — resolves, downloads, extracts, and installs ONE
# skill's release into $CENTRAL_DIR. Used both for `--skill <name>` (single
# invocation) and the discover-all loop (US-17 D8, one invocation per
# discovered name, since each skill has its own independently-tagged
# release). Exits 1 on any resolution/download/extraction failure.
# ---------------------------------------------------------------------------

install_one_skill_global() {
    local skill="$1"

    rm -rf "$CENTRAL_DIR"
    mkdir -p "$CENTRAL_DIR"

    echo "Resolving release for skill '$skill' in $REPO..."
    local resolve_status=0
    local tag
    tag="$(resolve_release_tag "$REPO" "$skill")" || resolve_status=$?
    if [ "$resolve_status" -ne 0 ]; then
        echo "Error: Failed to query releases for $REPO. Ensure gh CLI is authenticated or curl/wget is installed and has internet access." >&2
        rm -rf "$CENTRAL_DIR"
        exit 1
    fi
    if [ -z "$tag" ]; then
        print_no_release_error "$skill"
        rm -rf "$CENTRAL_DIR"
        exit 1
    fi
    echo "Resolved release: $tag"

    local temp_zip
    temp_zip=$(mktemp --suffix=.zip 2>/dev/null || mktemp "/tmp/${skill}-XXXXXX.zip")

    echo "Downloading release ZIP..."
    if ! download_release_zip "$REPO" "$tag" "$skill" "$temp_zip"; then
        echo "Error: Failed to download release ZIP. Ensure gh CLI is authenticated or curl/wget is installed and has internet access." >&2
        rm -f "$temp_zip"
        rm -rf "$CENTRAL_DIR"
        exit 1
    fi

    echo "Extracting release ZIP..."
    if ! command -v unzip &>/dev/null; then
        echo "Error: unzip is required but was not found." >&2
        rm -f "$temp_zip"
        exit 1
    fi
    if ! unzip -o "$temp_zip" -d "$CENTRAL_DIR" &>/dev/null; then
        echo "Error: extraction failed." >&2
        rm -rf "$CENTRAL_DIR"
        rm -f "$temp_zip"
        exit 1
    fi
    rm -f "$temp_zip"

    SKILL_NAME="$skill"
    install_skills "$CENTRAL_DIR" "$CENTRAL_DIR"
}

# ---------------------------------------------------------------------------
# install_skills — shared by LOCAL and GLOBAL mode
# ---------------------------------------------------------------------------

install_skills() {
    local payload_src="$1"
    local base_src="$2"

    if [ -f "$payload_src/lib/skill-payload.sh" ]; then
        # shellcheck disable=SC1091
        source "$payload_src/lib/skill-payload.sh"
    elif [ -f "$payload_src/cli/lib/skill-payload.sh" ]; then
        # shellcheck disable=SC1091
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
            # Flat payload (no skills/<name>/ subfolder) — install under the
            # ACTUAL requested skill name, never the base_src directory's own
            # basename (that literal-"skills" bug is the US-17 defect fix).
            skills+=("$SKILL_NAME")
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

# ---------------------------------------------------------------------------
# main — guarded so this file can be sourced (for unit tests) without running
# any installation side effects; only executes when run directly / piped to
# bash (curl <url> | bash), matching the existing `curl | bash` distribution
# contract.
# ---------------------------------------------------------------------------

main() {
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

    # No default skill when omitted in GLOBAL mode (US-17 D5 superseded by
    # D8) — an omitted `--skill` discovers and installs EVERY skill that has
    # a release, see the GLOBAL-mode branch below. LOCAL mode keeps its
    # existing auto-detect-all-skills behavior.

    # Skill-name validation — BEFORE any interpolation into a URL, jq filter,
    # regex, or filesystem path.
    if [ -n "$SKILL_NAME" ]; then
        validate_skill_name "$SKILL_NAME" || exit 1
    fi

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

    # 3. Installation Logic
    if [ "$LOCAL" = true ]; then
        echo "Installing in LOCAL Mode..."
        install_skills "$BASE_DIR" "$BASE_DIR"
    else
        echo "Installing in GLOBAL Mode..."
        if [ -n "$SKILL_NAME" ]; then
            install_one_skill_global "$SKILL_NAME"
        else
            # US-17 D8: no --skill given -> discover every distinct skill
            # name that has at least one <skill>-v* release in $REPO, then
            # install each one via the same single-skill flow. Never
            # silently no-ops and never defaults to a single skill.
            echo "No --skill specified; discovering all released skills in $REPO..."
            DISCOVER_STATUS=0
            DISCOVERED_NAMES="$(discover_all_skill_names "$REPO")" || DISCOVER_STATUS=$?
            if [ "$DISCOVER_STATUS" -ne 0 ]; then
                echo "Error: Failed to query releases for $REPO. Ensure gh CLI is authenticated or curl/wget is installed and has internet access." >&2
                exit 1
            fi

            SKILL_NAMES=()
            while IFS= read -r discovered_name; do
                [ -n "$discovered_name" ] && SKILL_NAMES+=("$discovered_name")
            done <<< "$DISCOVERED_NAMES"

            if [ ${#SKILL_NAMES[@]} -eq 0 ]; then
                echo "Error: no releases found in $REPO." >&2
                exit 1
            fi

            echo "Discovered skills: ${SKILL_NAMES[*]}"
            for discovered_skill in "${SKILL_NAMES[@]}"; do
                install_one_skill_global "$discovered_skill"
            done
        fi
    fi

    echo "Installation completed successfully!"
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
