#!/usr/bin/env bash
# Integration tests (Phase 1.1, 2.3, 2.4, 2.5, 5.1, 5.2, 5.3) for install.sh.
# Every case runs install.sh as a REAL subprocess with:
#   - HOME sandboxed to a throwaway temp dir (never touches the real user's
#     ~/.gemini, ~/.claude, ~/.hjagar, etc.)
#   - PATH restricted to `<fixtures/bin>:/usr/bin` so the script can ONLY see
#     the fake gh/curl (or neither, for gh-absent scenarios) — the real gh.exe
#     and curl.exe on this machine are excluded, so no test ever makes a real
#     network call.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/cli/install.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

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

# Restricted PATH: fake tools first (shadow real curl in /mingw64/bin), then
# real core utils (git, mkdir, sed, unzip, ...) — but NEVER the real GitHub
# CLI install dir, so gh-absent scenarios see a genuinely missing `gh`.
# The fixture's python3 shim (US-24 — build_agent_paths now shells out to
# python3 to parse cli/agent-targets.json) delegates to a real `python3`/
# `python` interpreter, since on some dev machines the PATH's own `python3`
# entry is a broken Windows Store app-execution-alias stub - so the real
# interpreter's directory (resolved from the *unrestricted* outer PATH, once,
# before sandboxing) is appended last, narrowly, without exposing the rest of
# the real PATH (gh in particular must stay unreachable for gh-absent tests).
REAL_PYTHON_DIR="$(dirname "$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)" 2>/dev/null || true)"
RESTRICTED_PATH="$FIXTURES/bin:/usr/bin:/mingw64/bin${REAL_PYTHON_DIR:+:$REAL_PYTHON_DIR}"

sandbox_home() { mktemp -d; }

# ---------------------------------------------------------------------------
# Phase 1.1 — threat matrix: malformed --skill values must exit 1 and MUST
# NOT invoke gh/curl at all (proven via FAKE_CALL_LOG staying empty/absent).
# ---------------------------------------------------------------------------
for bad in "a b" "../x" '$(id)'; do
    HOME_DIR="$(sandbox_home)"
    CALL_LOG="$(mktemp)"
    rm -f "$CALL_LOG"
    OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" FAKE_CALL_LOG="$CALL_LOG" \
        bash "$INSTALL_SH" --skill "$bad" 2>&1)
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
# Phase 2.3/2.4 — gh present: resolves highest matching tag, downloads exact
# tag's zip via `gh release download`.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
CALL_LOG="$(mktemp)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_CALL_LOG="$CALL_LOG" \
    FAKE_TAGS_LIST=$'req-discovery-v1.0.0\nreq-discovery-v1.10.0\nreq-discovery-v1.9.0' \
    FAKE_ZIP_SRC="$FIXTURES/data/req-discovery.zip" \
    bash "$INSTALL_SH" --skill req-discovery 2>&1)
STATUS=$?
assert_status "gh-present global install (req-discovery) succeeds" "0" "$STATUS"
assert_contains "gh-present resolves highest tag v1.10.0" "req-discovery-v1.10.0" "$OUT"
assert_true "gh-present installed skill dir exists under resolved name" \
    "$([ -f "$HOME_DIR/.gemini/skills/req-discovery/SKILL.md" ] && echo true || echo false)"
grep -q "release download req-discovery-v1.10.0" "$CALL_LOG" \
    && assert_true "gh release download called with exact resolved tag" "true" \
    || assert_true "gh release download called with exact resolved tag" "false"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Phase 5.1 — gh absent: curl fallback resolves tag + downloads zip. Achieved
# by omitting `gh` from the fixture bin entirely (RESTRICTED_PATH has no gh).
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_RELEASES_JSON="$FIXTURES/data/releases-req-discovery.json" \
    FAKE_ZIP_SRC="$FIXTURES/data/req-discovery.zip" \
    bash "$INSTALL_SH" --skill req-discovery 2>&1)
STATUS=$?
assert_status "gh-absent curl-fallback global install succeeds" "0" "$STATUS"
assert_contains "gh-absent resolves highest tag v1.10.0 via curl" "req-discovery-v1.10.0" "$OUT"
assert_true "gh-absent installed skill dir exists under resolved name" \
    "$([ -f "$HOME_DIR/.gemini/skills/req-discovery/SKILL.md" ] && echo true || echo false)"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Phase 5.2 — no matching tag: exact error text, exit 1, nothing installed
# under the requested (or any other) skill name.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_RELEASES_JSON="$FIXTURES/data/releases-empty-for-skill.json" \
    bash "$INSTALL_SH" --skill res-onboarding 2>&1)
STATUS=$?
assert_status "no-matching-tag exits 1" "1" "$STATUS"
assert_contains "no-matching-tag names the requested skill" "no released version found for skill 'res-onboarding'" "$OUT"
assert_contains "no-matching-tag suggests local install" "install.sh -l -p <path>" "$OUT"
assert_true "no-matching-tag installs nothing under requested name" \
    "$([ ! -d "$HOME_DIR/.gemini/skills/res-onboarding" ] && echo true || echo false)"
assert_true "no-matching-tag installs nothing under any other skill name" \
    "$([ ! -d "$HOME_DIR/.gemini/skills/us-refinement" ] && echo true || echo false)"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Phase 2.5 — flat-payload install-directory-naming defect fix: a flat
# payload (SKILL.md at root, no skills/<name>/ subfolder) whose directory
# basename is "flat-payload" must still install under the REQUESTED skill
# name, never "flat-payload" (the old `basename "$base_src"` bug) and never
# the literal "skills".
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
(
    # shellcheck disable=SC1090
    source "$INSTALL_SH"
    HOME="$HOME_DIR"
    SKILL_NAME="req-discovery"
    install_skills "$REPO_ROOT" "$FIXTURES/flat-payload"
) >/tmp/flat-out.$$ 2>&1
FLAT_STATUS=$?
assert_status "flat-payload install_skills succeeds" "0" "$FLAT_STATUS"
assert_true "flat-payload installs under requested skill name" \
    "$([ -f "$HOME_DIR/.gemini/skills/req-discovery/SKILL.md" ] && echo true || echo false)"
assert_true "flat-payload does NOT install under directory basename 'flat-payload'" \
    "$([ ! -d "$HOME_DIR/.gemini/skills/flat-payload" ] && echo true || echo false)"
assert_true "flat-payload does NOT install under literal 'skills'" \
    "$([ ! -d "$HOME_DIR/.gemini/skills/skills" ] && echo true || echo false)"
rm -f /tmp/flat-out.$$
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Phase 1.6 (US-17 D8) — omitted --skill in GLOBAL mode discovers and
# installs EVERY skill with a release, none skipped/duplicated. Never
# defaults to a single skill (D5 superseded).
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
CALL_LOG="$(mktemp)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_CALL_LOG="$CALL_LOG" \
    FAKE_TAGS_LIST=$'us-refinement-v1.0.0\nreq-discovery-v1.0.0\ntc-generator-v1.0.0' \
    FAKE_ZIP_SRC="$FIXTURES/data/flat-payload.zip" \
    bash "$INSTALL_SH" 2>&1)
STATUS=$?
assert_status "discover-all (omitted --skill) succeeds" "0" "$STATUS"
assert_contains "discover-all reports the discovered set" "Discovered skills:" "$OUT"
assert_true "discover-all installs us-refinement" \
    "$([ -f "$HOME_DIR/.gemini/skills/us-refinement/SKILL.md" ] && echo true || echo false)"
assert_true "discover-all installs req-discovery" \
    "$([ -f "$HOME_DIR/.gemini/skills/req-discovery/SKILL.md" ] && echo true || echo false)"
assert_true "discover-all installs tc-generator" \
    "$([ -f "$HOME_DIR/.gemini/skills/tc-generator/SKILL.md" ] && echo true || echo false)"
DOWNLOAD_COUNT=$(grep -c "release download" "$CALL_LOG" 2>/dev/null || true)
assert_eq "discover-all downloads exactly once per discovered skill (none skipped/duplicated)" "3" "${DOWNLOAD_COUNT:-0}"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# Phase 1.7 (US-17 D8) — omitted --skill with zero matching releases in the
# repo errors by name, exit 1, never silently no-ops.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    FAKE_RELEASES_JSON="$FIXTURES/data/releases-empty-list.json" \
    bash "$INSTALL_SH" 2>&1)
STATUS=$?
assert_status "discover-all with zero releases exits 1" "1" "$STATUS"
assert_contains "discover-all with zero releases names the repo" "no releases found in hjagar/hjagar-skills" "$OUT"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# LOCAL mode approval test: unchanged filesystem-only behavior still works.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    bash "$INSTALL_SH" --local --path "$REPO_ROOT" --skill req-discovery 2>&1)
STATUS=$?
assert_status "LOCAL mode install (req-discovery) succeeds" "0" "$STATUS"
assert_true "LOCAL mode installs under requested skill name" \
    "$([ -f "$HOME_DIR/.gemini/skills/req-discovery/SKILL.md" ] && echo true || echo false)"
rm -rf "$HOME_DIR"

# ---------------------------------------------------------------------------
# US-23 — Kiro is a kept, tested special case: a flat steering file must be
# generated at ~/.kiro/steering/<skill>.md alongside the folder-convention
# agent dirs, with `inclusion: always` injected as the first key inside the
# copied SKILL.md's YAML frontmatter.
# ---------------------------------------------------------------------------
HOME_DIR="$(sandbox_home)"
OUT=$(HOME="$HOME_DIR" PATH="$RESTRICTED_PATH" \
    bash "$INSTALL_SH" --local --path "$REPO_ROOT" --skill req-discovery 2>&1)
STATUS=$?
KIRO_FILE="$HOME_DIR/.kiro/steering/req-discovery.md"
assert_status "LOCAL mode install (req-discovery) succeeds for Kiro case" "0" "$STATUS"
assert_true "Kiro steering file is generated" \
    "$([ -f "$KIRO_FILE" ] && echo true || echo false)"
assert_eq "Kiro steering file's first line is the '---' frontmatter delimiter" \
    "---" "$(head -n 1 "$KIRO_FILE")"
assert_eq "Kiro steering file injects 'inclusion: always' as the second line" \
    "inclusion: always" "$(sed -n '2p' "$KIRO_FILE")"
rm -rf "$HOME_DIR"

echo ""
echo "install-integration: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
