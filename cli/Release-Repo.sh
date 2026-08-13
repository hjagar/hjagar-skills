#!/usr/bin/env bash
set -euo pipefail

# Monorepo publish target (US-17 D6). Release-Repo keeps publishing to
# `origin` using the existing <skill>-v* tag scheme (no --repo flag is added
# to `gh release create` — D2). This constant is only used to verify that
# `gh` actually resolved that same repo before any tag or push happens.
REPO="hjagar/hjagar-skills"

# ---------------------------------------------------------------------------
# Pure / testable helper functions
# ---------------------------------------------------------------------------

# Pure (US-17 D6 preflight guard): compares the repo `gh` actually resolved
# against the expected monorepo publish target. Returns 0 on an exact match.
# On mismatch, or when $actual is empty (gh failed to resolve anything),
# prints an error to stderr and returns 1 - callers MUST abort (create no
# tag, push nothing) on any non-zero return. Never touches the network
# itself - safe to unit test with canned strings.
check_publish_target() {
    local expected="$1"
    local actual="$2"
    if [ -z "$actual" ]; then
        echo "Error: could not resolve the publish target repo via 'gh repo view'. Ensure gh is authenticated and a GitHub remote is configured. Aborting before any tag or push - nothing was created." >&2
        return 1
    fi
    if [ "$actual" != "$expected" ]; then
        echo "Error: publish target mismatch. 'gh repo view' resolved '$actual', expected '$expected'. Aborting before any tag or push - nothing was created. Check for an extra remote (e.g. an 'upstream' remote) confusing gh's default repo resolution." >&2
        return 1
    fi
    return 0
}

# Network (US-17 D6): resolves the base repo `gh` would target for release
# operations in the current directory. Prints "owner/name" on success, prints
# nothing on failure (gh not authenticated, no remote configured, ambiguous
# resolution, etc.) - callers must treat empty output as failure via
# check_publish_target, never as a legitimate empty target.
resolve_publish_target_repo() {
    gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true
}

# Stages a skill's release payload into a scratch staging directory as:
#   skills/<name>/**              (the skill's own contents, nested - not flat)
#   cli/lib/skill-payload.sh
#   cli/lib/skill-payload.ps1
#   cli/agent-targets.json        (US-24 - manifest read by skill-payload.{sh,ps1})
# Pure filesystem staging - no `zip` binary required, safe to unit test
# without it. Mirrors the monorepo's own layout (US-17 D4) so
# `install_skills`'s `skills/<name>` resolution branch succeeds after
# extraction - replaces the old flat `zip -r . ` run from inside $SKILL_DIR,
# which omitted cli/lib entirely and installed under the wrong name.
stage_release_payload() {
    local repo_root="$1" skill_name="$2" skill_dir="$3" staging_dir="$4"

    rm -rf "$staging_dir"
    mkdir -p "$staging_dir/skills" "$staging_dir/cli/lib"
    cp -r "$skill_dir" "$staging_dir/skills/$skill_name"
    cp "$repo_root/cli/lib/skill-payload.sh" "$staging_dir/cli/lib/skill-payload.sh"
    cp "$repo_root/cli/lib/skill-payload.ps1" "$staging_dir/cli/lib/skill-payload.ps1"
    cp "$repo_root/cli/agent-targets.json" "$staging_dir/cli/agent-targets.json"
}

# Zips an already-staged release payload (see stage_release_payload) into
# $zip_path, with `skills/` and `cli/` as the archive's top-level entries.
# Requires the `zip` binary - kept as a separate step so staging logic
# remains unit-testable in environments without it.
zip_release_payload() {
    local staging_dir="$1" zip_path="$2"
    rm -f "$zip_path"
    mkdir -p "$(dirname "$zip_path")"
    (cd "$staging_dir" && zip -rq "$zip_path" skills cli)
}

# ---------------------------------------------------------------------------
# Entry point (guarded - see bottom of file)
# ---------------------------------------------------------------------------

main() {
    echo "=== Release-Repo ==="

    command -v git        &>/dev/null || { echo "Error: git not found." >&2; exit 1; }
    command -v python3    &>/dev/null || { echo "Error: python3 not found." >&2; exit 1; }
    command -v gh         &>/dev/null || { echo "Error: gh not found." >&2; exit 1; }
    command -v shellcheck &>/dev/null || { echo "Error: shellcheck not found. Install: sudo apt install shellcheck / brew install shellcheck" >&2; exit 1; }
    command -v zip        &>/dev/null || { echo "Error: zip not found. Install: sudo apt install zip / brew install zip" >&2; exit 1; }

    REPO_ROOT=$(git rev-parse --show-toplevel)
    cd "$REPO_ROOT"

    RELEASE_TYPE=""
    SKILL_NAME=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skill)
                SKILL_NAME="${2:-}"
                shift 2
                ;;
            patch|minor|major)
                RELEASE_TYPE="$1"
                shift
                ;;
            *)
                if [[ -z "$SKILL_NAME" && -d "$REPO_ROOT/skills/$1" ]]; then
                    SKILL_NAME="$1"
                elif [[ -z "$RELEASE_TYPE" && "$1" =~ ^(patch|minor|major)$ ]]; then
                    RELEASE_TYPE="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$SKILL_NAME" ]]; then
        echo "Available skills:"
        for d in "$REPO_ROOT/skills"/*/; do
            [[ -d "$d" ]] && echo "  - $(basename "$d")"
        done
        read -rp "Skill to release: " SKILL_NAME
    fi

    SKILL_DIR="$REPO_ROOT/skills/$SKILL_NAME"
    SKILL_MD="$SKILL_DIR/SKILL.md"

    if [[ ! -d "$SKILL_DIR" ]]; then
        echo "Error: Skill directory not found at $SKILL_DIR" >&2
        exit 1
    fi

    if [[ ! -f "$SKILL_MD" ]]; then
        echo "Error: SKILL.md not found at $SKILL_MD" >&2
        exit 1
    fi

    if [[ -z "$RELEASE_TYPE" ]]; then
        read -rp "Release type (patch/minor/major): " RELEASE_TYPE
    fi

    if [[ ! "$RELEASE_TYPE" =~ ^(patch|minor|major)$ ]]; then
        echo "Error: release type must be patch, minor, or major." >&2
        exit 1
    fi

    echo "[1/6] Quality gate for skill: $SKILL_NAME..."

    # Safety pre-flight checks
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ]; then
        echo "Error: Releases must be created from the main branch. Current branch is: $current_branch" >&2
        exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "Error: Working tree is dirty. Commit or stash changes before releasing." >&2
        exit 1
    fi

    GATE_FAILED=false
    for f in *.sh cli/lib/*.sh "$SKILL_DIR"/scripts/*.sh "$SKILL_DIR"/tests/*.sh; do
        [[ -f "$f" ]] || continue
        echo "  checking $f..."
        if ! shellcheck -x "$f"; then
            GATE_FAILED=true
        fi
    done
    if [[ "$GATE_FAILED" == true ]]; then
        echo "shellcheck failed. Aborting - nothing was created." >&2
        exit 1
    fi

    # shellcheck source=cli/lib/quality-gate.sh
    source "$REPO_ROOT/cli/lib/quality-gate.sh"
    if ! run_quality_gate "$REPO_ROOT" "$SKILL_NAME"; then
        echo "Quality gate failed for $SKILL_NAME. Aborting." >&2
        exit 1
    fi
    echo "  All quality gate checks passed."

    echo "[2/6] Version bump..."
    CURRENT_VER=$(python3 -c "import sys, re; content=open(sys.argv[1], encoding='utf-8').read(); fm=re.search(r'(?s)\A---\r?\n(.*?)\r?\n---', content); ver=re.search(r'version:\s*\"?(?:v)?([0-9\.]+)\"?', fm.group(1)) if fm else None; print(ver.group(1) if ver else '1.0.0')" "$SKILL_MD")

    MAJOR=$(echo "$CURRENT_VER" | cut -d. -f1)
    MINOR=$(echo "$CURRENT_VER" | cut -d. -f2)
    PATCH=$(echo "$CURRENT_VER" | cut -d. -f3)

    case "$RELEASE_TYPE" in
        major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR+1)); PATCH=0 ;;
        patch) PATCH=$((PATCH+1)) ;;
    esac

    NEXT_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
    TAG_NAME="${SKILL_NAME}-${NEXT_VERSION}"
    echo "  $SKILL_NAME: v$CURRENT_VER -> $NEXT_VERSION ($RELEASE_TYPE)"

    read -rp "Create release $TAG_NAME? (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Cancelled. Nothing was created."
        exit 0
    fi

    echo "[3/6] Packaging..."
    PLAIN_VERSION="${NEXT_VERSION#v}"
    awk -v ver="$PLAIN_VERSION" '
        BEGIN { fm = 0; bumped = 0 }
        /^---[[:space:]]*\r?$/ {
            fm++
            if (fm == 2 && !bumped) { print "metadata:"; print "  version: \"" ver "\""; bumped = 1 }
            print
            next
        }
        fm == 1 && /^[[:space:]]*version:[[:space:]]*"?v?[0-9.]+"?[[:space:]]*\r?$/ {
            print "  version: \"" ver "\""
            bumped = 1
            next
        }
        /<!-- version: v[0-9.]* -->/ { next }
        { print }
    ' "$SKILL_MD" > "$SKILL_MD.tmp" && mv "$SKILL_MD.tmp" "$SKILL_MD"

    echo "  Creating version bump commit..."
    git add "$SKILL_MD"
    git commit -m "chore(release): bump $SKILL_NAME version to $NEXT_VERSION" >/dev/null

    BUILD_DIR="$REPO_ROOT/build"
    STAGING_DIR="$BUILD_DIR/.staging"
    ZIP_PATH="$BUILD_DIR/$SKILL_NAME.zip"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    stage_release_payload "$REPO_ROOT" "$SKILL_NAME" "$SKILL_DIR" "$STAGING_DIR"
    zip_release_payload "$STAGING_DIR" "$ZIP_PATH"
    rm -rf "$STAGING_DIR"
    echo "  Created build/$SKILL_NAME.zip"

    echo "[4/6] Verifying publish target..."
    ACTUAL_REPO="$(resolve_publish_target_repo)"
    if ! check_publish_target "$REPO" "$ACTUAL_REPO"; then
        exit 1
    fi
    echo "  Publish target confirmed: $REPO"

    echo "[5/6] Tag + push..."
    if ! git tag -a "$TAG_NAME" -m "Release $SKILL_NAME $NEXT_VERSION"; then
        echo "git tag failed. Aborting." >&2
        exit 1
    fi
    if ! git push origin main --follow-tags; then
        echo "git push failed. Aborting." >&2
        exit 1
    fi
    echo "  Tagged and pushed $TAG_NAME."

    echo "[6/6] Publishing GitHub release..."
    if ! gh release create "$TAG_NAME" "$ZIP_PATH" --title "$SKILL_NAME $NEXT_VERSION" --generate-notes; then
        echo "gh release create failed (check 'gh auth status'). Tag $TAG_NAME is already pushed - re-run after auth to reuse it." >&2
        exit 1
    fi
    rm -rf "$BUILD_DIR"

    echo ""
    echo "Done. Release $TAG_NAME published."
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
