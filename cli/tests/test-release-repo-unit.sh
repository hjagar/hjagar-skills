#!/usr/bin/env bash
# Unit tests (PR2, US-17 Phase 4.1/4.2): check_publish_target (D6 preflight
# guard) + stage_release_payload/zip_release_payload (D4 zip layout) in
# Release-Repo.sh. Sourcing Release-Repo.sh is safe because it is guarded
# (`if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]`) — no git tag/push/gh release
# create/prerequisite-check side effects run on source.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_REPO_SH="$SCRIPT_DIR/../Release-Repo.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL+1))
        echo "NOT OK - $desc (expected [$expected], got [$actual])"
    fi
}

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL+1))
        echo "NOT OK - $desc (expected exit $expected, got $actual)"
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$((PASS+1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL+1))
        echo "NOT OK - $desc (expected [$haystack] to contain [$needle])"
    fi
}

assert_true() {
    local desc="$1" cond="$2"
    if [ "$cond" = "true" ]; then
        PASS=$((PASS+1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL+1))
        echo "NOT OK - $desc"
    fi
}

# --- Sourcing safety --------------------------------------------------------
# Sourcing must be a pure no-op (no prerequisite checks, no banner, no git
# side effects) — that's the whole point of guarding main().
SOURCE_OUTPUT="$(
    # shellcheck disable=SC1090
    source "$RELEASE_REPO_SH"
)"
assert_eq "sourcing Release-Repo.sh produces no output (main() did not run)" "" "$SOURCE_OUTPUT"

# shellcheck disable=SC1090
source "$RELEASE_REPO_SH"
# Release-Repo.sh sets `set -euo pipefail`; sourcing it propagates that into
# THIS shell. Turn it back off so assertion helpers can inspect non-zero exit
# codes below instead of the test script aborting on the first expected
# failure.
set +e

assert_eq "REPO constant is the monorepo" "hjagar/hjagar-skills" "$REPO"
assert_true "main is defined as a function after sourcing" "$(declare -F main >/dev/null 2>&1 && echo true || echo false)"

# --- check_publish_target (US-17 D6 preflight, pure) ------------------------

check_publish_target "hjagar/hjagar-skills" "hjagar/hjagar-skills"
assert_status "matching publish target accepted" "0" "$?"

ERR_OUTPUT="$(check_publish_target "hjagar/hjagar-skills" "someone-else/other-repo" 2>&1)"
STATUS=$?
assert_status "mismatched publish target rejected" "1" "$STATUS"
assert_contains "mismatch error names the resolved repo" "$ERR_OUTPUT" "someone-else/other-repo"
assert_contains "mismatch error names the expected repo" "$ERR_OUTPUT" "hjagar/hjagar-skills"
assert_contains "mismatch error mentions aborting before tag/push" "$ERR_OUTPUT" "Aborting before any tag or push"

ERR_OUTPUT_EMPTY="$(check_publish_target "hjagar/hjagar-skills" "" 2>&1)"
STATUS=$?
assert_status "empty resolved repo (gh failed) rejected" "1" "$STATUS"
assert_contains "empty-resolution error explains the cause" "$ERR_OUTPUT_EMPTY" "could not resolve the publish target repo"

# Triangulation: a second, different mismatch pair must also be rejected.
check_publish_target "hjagar/hjagar-skills" "hjagar/us-refinement" >/dev/null 2>&1
assert_status "second mismatched pair (legacy mirror repo) also rejected" "1" "$?"

# --- stage_release_payload (US-17 D4, pure filesystem staging) -------------

STAGE_TMP="$(mktemp -d)"
FAKE_REPO_ROOT="$STAGE_TMP/repo-root"
FAKE_SKILL_DIR="$STAGE_TMP/repo-root/skills/req-discovery"
STAGING_DIR="$STAGE_TMP/staging"

mkdir -p "$FAKE_REPO_ROOT/cli/lib" "$FAKE_SKILL_DIR/assets"
echo "# req-discovery SKILL.md" > "$FAKE_SKILL_DIR/SKILL.md"
echo "asset content" > "$FAKE_SKILL_DIR/assets/example.txt"
echo "#!/usr/bin/env bash" > "$FAKE_REPO_ROOT/cli/lib/skill-payload.sh"
echo "# ps1 payload" > "$FAKE_REPO_ROOT/cli/lib/skill-payload.ps1"
echo '{"targets":[]}' > "$FAKE_REPO_ROOT/cli/agent-targets.json"

stage_release_payload "$FAKE_REPO_ROOT" "req-discovery" "$FAKE_SKILL_DIR" "$STAGING_DIR"

assert_true "staged skill SKILL.md exists under skills/<name>" \
    "$([ -f "$STAGING_DIR/skills/req-discovery/SKILL.md" ] && echo true || echo false)"
assert_eq "staged skill SKILL.md content matches source" \
    "$(cat "$FAKE_SKILL_DIR/SKILL.md")" "$(cat "$STAGING_DIR/skills/req-discovery/SKILL.md")"
assert_true "staged skill nested asset preserved (not flattened)" \
    "$([ -f "$STAGING_DIR/skills/req-discovery/assets/example.txt" ] && echo true || echo false)"
assert_true "cli/lib/skill-payload.sh staged" \
    "$([ -f "$STAGING_DIR/cli/lib/skill-payload.sh" ] && echo true || echo false)"
assert_true "cli/lib/skill-payload.ps1 staged" \
    "$([ -f "$STAGING_DIR/cli/lib/skill-payload.ps1" ] && echo true || echo false)"
assert_eq "staged skill-payload.sh content matches source" \
    "$(cat "$FAKE_REPO_ROOT/cli/lib/skill-payload.sh")" "$(cat "$STAGING_DIR/cli/lib/skill-payload.sh")"
assert_true "no flat top-level SKILL.md (legacy flat-zip regression not present)" \
    "$([ ! -f "$STAGING_DIR/SKILL.md" ] && echo true || echo false)"
assert_true "cli/agent-targets.json staged (US-24 manifest)" \
    "$([ -f "$STAGING_DIR/cli/agent-targets.json" ] && echo true || echo false)"
assert_eq "staged agent-targets.json content matches source" \
    "$(cat "$FAKE_REPO_ROOT/cli/agent-targets.json")" "$(cat "$STAGING_DIR/cli/agent-targets.json")"

# Triangulation: a second, differently-named skill with different content
# stages correctly too, and stage_release_payload's rm -rf leaves no
# cross-contamination from the first call.
FAKE_SKILL_DIR_2="$STAGE_TMP/repo-root/skills/tc-generator"
mkdir -p "$FAKE_SKILL_DIR_2"
echo "# tc-generator SKILL.md" > "$FAKE_SKILL_DIR_2/SKILL.md"

stage_release_payload "$FAKE_REPO_ROOT" "tc-generator" "$FAKE_SKILL_DIR_2" "$STAGING_DIR"

assert_true "second staging call: staged under the NEW skill name" \
    "$([ -f "$STAGING_DIR/skills/tc-generator/SKILL.md" ] && echo true || echo false)"
assert_true "second staging call: previous skill's directory is gone (rm -rf, no cross-contamination)" \
    "$([ ! -d "$STAGING_DIR/skills/req-discovery" ] && echo true || echo false)"

# --- zip_release_payload (US-17 D4, requires the `zip` binary) -------------

if command -v zip &>/dev/null && command -v unzip &>/dev/null; then
    ZIP_PATH="$STAGE_TMP/build/tc-generator.zip"
    zip_release_payload "$STAGING_DIR" "$ZIP_PATH"

    assert_true "zip_release_payload created the zip file" \
        "$([ -f "$ZIP_PATH" ] && echo true || echo false)"

    ZIP_LISTING="$(unzip -l "$ZIP_PATH")"
    assert_contains "zip contains skills/<name>/SKILL.md" "$ZIP_LISTING" "skills/tc-generator/SKILL.md"
    assert_contains "zip contains cli/lib/skill-payload.sh" "$ZIP_LISTING" "cli/lib/skill-payload.sh"
    assert_contains "zip contains cli/lib/skill-payload.ps1" "$ZIP_LISTING" "cli/lib/skill-payload.ps1"
    assert_contains "zip contains cli/agent-targets.json (US-24 manifest)" "$ZIP_LISTING" "cli/agent-targets.json"

    # Legacy flat-zip regression check: the old `zip -r . ` behavior (run from
    # inside $SKILL_DIR) would list a bare top-level "SKILL.md", never
    # "skills/<name>/SKILL.md" and never any "cli/lib/*" entry at all.
    FLAT_MATCH="$(echo "$ZIP_LISTING" | grep -E '  SKILL\.md$' || true)"
    assert_eq "no bare top-level SKILL.md entry (legacy flat-zip regression prevented)" "" "$FLAT_MATCH"
else
    echo "SKIP - zip_release_payload tests (zip/unzip not both on PATH in this environment)"
fi

rm -rf "$STAGE_TMP"

echo ""
echo "release-repo-unit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
