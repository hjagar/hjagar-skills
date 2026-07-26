#!/usr/bin/env bash
set -euo pipefail

echo "=== Release-Repo ==="

command -v git        &>/dev/null || { echo "Error: git not found."; exit 1; }
command -v python3    &>/dev/null || { echo "Error: python3 not found."; exit 1; }
command -v gh         &>/dev/null || { echo "Error: gh not found."; exit 1; }
command -v shellcheck &>/dev/null || { echo "Error: shellcheck not found. Install: sudo apt install shellcheck / brew install shellcheck"; exit 1; }
command -v zip        &>/dev/null || { echo "Error: zip not found. Install: sudo apt install zip / brew install zip"; exit 1; }

RELEASE_TYPE="${1:-}"
if [[ -z "$RELEASE_TYPE" ]]; then
    read -rp "Release type (patch/minor/major): " RELEASE_TYPE
fi
if [[ ! "$RELEASE_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo "Error: release type must be patch, minor, or major."
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "[1/5] Quality gate..."

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
for f in *.sh lib/*.sh; do
    [[ -f "$f" ]] || continue
    echo "  checking $f..."
    if ! shellcheck -x "$f"; then
        GATE_FAILED=true
    fi
done
if [[ "$GATE_FAILED" == true ]]; then
    echo "shellcheck failed. Aborting - nothing was created."
    exit 1
fi

echo "  checking Python schema validation on mock_valid_us.md..."
if ! python3 scripts/validate_refinement.py tests/mock_valid_us.md; then
    echo "Validation failed on mock_valid_us.md. Aborting."
    exit 1
fi
echo "  checking Python schema validation on mock_invalid_us.md..."
if python3 scripts/validate_refinement.py tests/mock_invalid_us.md &>/dev/null; then
    echo "Validation unexpectedly succeeded on mock_invalid_us.md. Aborting."
    exit 1
fi
echo "  All quality gate checks passed."

echo "[2/5] Version bump..."
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [[ -z "$LAST_TAG" ]]; then
    NEXT_VERSION="v1.0.0"
    echo "  No existing tags. Proposing first release $NEXT_VERSION."
else
    VER="${LAST_TAG#v}"
    MAJOR=$(echo "$VER" | cut -d. -f1)
    MINOR=$(echo "$VER" | cut -d. -f2)
    PATCH=$(echo "$VER" | cut -d. -f3)
    case "$RELEASE_TYPE" in
        major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR+1)); PATCH=0 ;;
        patch) PATCH=$((PATCH+1)) ;;
    esac
    NEXT_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
    echo "  $LAST_TAG -> $NEXT_VERSION ($RELEASE_TYPE)"
fi

read -rp "Create release $NEXT_VERSION? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled. Nothing was created."
    exit 0
fi

echo "[3/5] Packaging..."

# Bump metadata.version in the SKILL.md frontmatter, scoped to the
# frontmatter block only (migrates the legacy <!-- version: vX.Y.Z -->
# comment format the first time it encounters it), CRLF-tolerant
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
' "SKILL.md" > "SKILL.md.tmp" && mv "SKILL.md.tmp" "SKILL.md"

# Commit version bump to workspace git history
echo "  Creating version bump commit..."
git add SKILL.md
git commit -m "chore(release): bump version to $NEXT_VERSION" >/dev/null

BUILD_DIR="$REPO_ROOT/build"
ZIP_PATH="$BUILD_DIR/us-refinement.zip"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy source files to build directory
cp SKILL.md "$BUILD_DIR/"
cp us-refinement-uninstall.ps1 "$BUILD_DIR/"
cp us-refinement-uninstall.sh "$BUILD_DIR/"
cp update.ps1 "$BUILD_DIR/"
cp update.sh "$BUILD_DIR/"
cp -r scripts "$BUILD_DIR/"
cp -r tests "$BUILD_DIR/"
cp -r lib "$BUILD_DIR/"

cd "$BUILD_DIR"
zip -r "$ZIP_PATH" SKILL.md us-refinement-uninstall.ps1 us-refinement-uninstall.sh update.ps1 update.sh scripts tests lib
cd "$REPO_ROOT"
echo "  Created build/us-refinement.zip"

echo "[4/5] Tag + push..."
if ! git tag -a "$NEXT_VERSION" -m "Release $NEXT_VERSION"; then
    echo "git tag failed. Aborting."
    exit 1
fi
if ! git push origin main --follow-tags; then
    echo "git push failed. Aborting."
    exit 1
fi
echo "  Tagged and pushed $NEXT_VERSION."

echo "[5/5] Publishing GitHub release..."
if ! gh release create "$NEXT_VERSION" "$ZIP_PATH" --generate-notes; then
    echo "gh release create failed (check 'gh auth status'). Tag $NEXT_VERSION is already pushed - re-run after auth to reuse it."
    exit 1
fi
rm -rf "$BUILD_DIR"

echo ""
echo "Done. Release $NEXT_VERSION published."
