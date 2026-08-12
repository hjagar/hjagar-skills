#!/usr/bin/env bash
# Integration tests (Phase 1.1, 3.1, 3.2, 5.1, 5.2) for update.sh. Every case
# runs update.sh as a REAL subprocess with HOME sandboxed and PATH restricted
# the same way as test-install-integration.sh — no real network call ever
# happens.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UPDATE_SH="$REPO_ROOT/cli/update.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
RESTRICTED_PATH="$FIXTURES/bin:/usr/bin:/mingw64/bin"

PASS=0
FAIL=0

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1)); echo "ok - $desc"
    else
        FAIL=$((FAIL+1)); echo "NOT OK - $desc (expected exit $expected, got $actual)"
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        PASS=$((PASS+1)); echo "ok - $desc"
    else
        FAIL=$((FAIL+1)); echo "NOT OK - $desc (expected to find [$needle])"
    fi
}

assert_true() {
    local desc="$1" cond="$2"
    if [ "$cond" = "true" ]; then
        PASS=$((PASS+1)); echo "ok - $desc"
    else
        FAIL=$((FAIL+1)); echo "NOT OK - $desc"
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1)); echo "ok - $desc"
    else
        FAIL=$((FAIL+1)); echo "NOT OK - $desc (expected [$expected], got [$actual])"
    fi
}

sandbox_home() { mktemp -d; }

seed_installed_skill() {
    local home_dir="$1" skill="$2" version="$3"
    mkdir -p "$home_dir/.hjagar/skills/skills/$skill"
    cat > "$home_dir/.hjagar/skills/skills/$skill/SKILL.md" <<EOF
---
name: $skill
metadata:
  version: $version
---
body
EOF
    mkdir -p "$home_dir/.hjagar/skills/cli/lib"
    cp "$REPO_ROOT/cli/lib/skill-payload.sh" "$home_dir/.hjagar/skills/cli/lib/skill-payload.sh"
    mkdir -p "$home_dir/.gemini/skills/$skill"
}

# ---------------------------------------------------------------------------
# Threat matrix — malformed --skill values exit 1, no network call.
# ---------------------------------------------------------------------------
for bad in "a b" "../x" '$(id)'; do
    HOME_DIR="$(sandbox_home)"
    CALL_LOG="$(mktemp)"
    rm -f "$CALL_LOG"
    HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" FAKE_CALL_LOG="$CALL_LOG" \
        bash "$UPDATE_SH" --skill "$bad" >/dev/null 2>&1
    STATUS=$?
    assert_status "malformed --skill '$bad' exits 1" "1" "$STATUS"
    if [ -f "$CALL_LOG" ]; then
        assert_true "malformed --skill '$bad' made no network call" "false"
    else
        assert_true "malformed --skill '$bad' made no network call" "true"
    fi
    rm -rf "$HOME_DIR"
done

# ---------------------------------------------------------------------------
# gh-present: resolves highest tag, downloads + updates.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
seed_installed_skill "$HOME_DIR" "req-discovery" "v1.0.0"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_TAGS_LIST=$'req-discovery-v1.0.0\nreq-discovery-v1.10.0\nreq-discovery-v1.9.0' \
    FAKE_ZIP_SRC="$FIXTURES/data/req-discovery.zip" \
    bash "$UPDATE_SH" --skill req-discovery 2>&1)
STATUS=$?
assert_status "gh-present update (req-discovery) succeeds" "0" "$STATUS"
assert_contains "gh-present resolves highest tag v1.10.0" "Latest remote version: v1.10.0" "$OUT"
assert_contains "gh-present reports update completion" "Update completed successfully to version v1.10.0" "$OUT"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# gh-absent: curl fallback resolves + downloads.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
seed_installed_skill "$HOME_DIR" "req-discovery" "v1.0.0"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_RELEASES_JSON="$FIXTURES/data/releases-req-discovery.json" \
    FAKE_ZIP_SRC="$FIXTURES/data/req-discovery.zip" \
    bash "$UPDATE_SH" --skill req-discovery 2>&1)
STATUS=$?
assert_status "gh-absent curl-fallback update succeeds" "0" "$STATUS"
assert_contains "gh-absent resolves highest tag via curl" "Latest remote version: v1.10.0" "$OUT"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Already up to date — no download attempted, exit 0.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
seed_installed_skill "$HOME_DIR" "req-discovery" "v1.10.0"
CALL_LOG="$(mktemp)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" FAKE_CALL_LOG="$CALL_LOG" \
    FAKE_TAGS_LIST=$'req-discovery-v1.0.0\nreq-discovery-v1.10.0' \
    bash "$UPDATE_SH" --skill req-discovery 2>&1)
STATUS=$?
assert_status "already-up-to-date exits 0" "0" "$STATUS"
assert_contains "already-up-to-date message" "You are already on the latest version: v1.10.0" "$OUT"
if grep -q 'release download\|gh release' "$CALL_LOG" 2>/dev/null; then
    assert_true "already-up-to-date does not attempt a download" "false"
else
    assert_true "already-up-to-date does not attempt a download" "true"
fi
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# No matching tag — exact error text, exit 1.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
seed_installed_skill "$HOME_DIR" "res-onboarding" "v1.0.0"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_RELEASES_JSON="$FIXTURES/data/releases-empty-for-skill.json" \
    bash "$UPDATE_SH" --skill res-onboarding 2>&1)
STATUS=$?
assert_status "no-matching-tag update exits 1" "1" "$STATUS"
assert_contains "no-matching-tag names the requested skill" "no released version found for skill 'res-onboarding'" "$OUT"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Phase 3.4 (US-17 D8) — omitted --skill updates EVERY locally-installed
# skill, each via its own resolved tag. Never defaults to only us-refinement
# (D5 superseded).
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
seed_installed_skill "$HOME_DIR" "req-discovery" "v1.0.0"
seed_installed_skill "$HOME_DIR" "tc-generator" "v1.0.0"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_TAGS_LIST=$'req-discovery-v1.10.0\ntc-generator-v2.0.0' \
    FAKE_ZIP_SRC="$FIXTURES/data/req-discovery.zip" \
    bash "$UPDATE_SH" 2>&1)
STATUS=$?
assert_status "omitted --skill updates every locally-installed skill" "0" "$STATUS"
assert_contains "omitted --skill resolves req-discovery" "Resolving release for skill 'req-discovery'" "$OUT"
assert_contains "omitted --skill resolves tc-generator" "Resolving release for skill 'tc-generator'" "$OUT"
if printf '%s' "$OUT" | grep -q "Resolving release for skill 'us-refinement'"; then
    assert_true "omitted --skill never defaults to only us-refinement" "false"
else
    assert_true "omitted --skill never defaults to only us-refinement" "true"
fi
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Phase 3.4 — omitted --skill with nothing locally installed errors by name,
# exit 1, never silently no-ops.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" bash "$UPDATE_SH" 2>&1)
STATUS=$?
assert_status "omitted --skill with nothing installed exits 1" "1" "$STATUS"
assert_contains "omitted --skill with nothing installed names the error" \
    "skills are not installed globally at" "$OUT"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# US-23 — Kiro update is conditional on prior Kiro install: a pre-existing
# steering file must be regenerated (frontmatter re-injected), but an absent
# one must NOT be created by update.sh.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
seed_installed_skill "$HOME_DIR" "req-discovery" "v1.0.0"
mkdir -p "$HOME_DIR/.kiro/steering"
printf -- '---\nname: req-discovery\n---\nold body\n' > "$HOME_DIR/.kiro/steering/req-discovery.md"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_TAGS_LIST=$'req-discovery-v1.0.0\nreq-discovery-v1.10.0' \
    FAKE_ZIP_SRC="$FIXTURES/data/req-discovery.zip" \
    bash "$UPDATE_SH" --skill req-discovery 2>&1)
STATUS=$?
assert_status "update regenerates a pre-existing Kiro steering file: succeeds" "0" "$STATUS"
assert_eq "update regenerates a pre-existing Kiro steering file: re-injects frontmatter" \
    "inclusion: always" "$(sed -n '2p' "$HOME_DIR/.kiro/steering/req-discovery.md")"
rm -rf "$HOME_DIR"

HOME_DIR="$(sandbox_home)"
seed_installed_skill "$HOME_DIR" "req-discovery" "v1.0.0"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_TAGS_LIST=$'req-discovery-v1.0.0\nreq-discovery-v1.10.0' \
    FAKE_ZIP_SRC="$FIXTURES/data/req-discovery.zip" \
    bash "$UPDATE_SH" --skill req-discovery 2>&1)
STATUS=$?
assert_status "update leaves absent Kiro steering file untouched: succeeds" "0" "$STATUS"
assert_true "update leaves absent Kiro steering file untouched: no file created" \
    "$([ ! -f "$HOME_DIR/.kiro/steering/req-discovery.md" ] && echo true || echo false)"
rm -rf "$HOME_DIR"

echo ""
echo "update-integration: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
