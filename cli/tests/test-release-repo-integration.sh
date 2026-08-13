#!/usr/bin/env bash
# Integration tests (PR2, US-17 Phase 1.3 / 4.1) for Release-Repo.sh's D6
# preflight guard. Runs Release-Repo.sh as a REAL subprocess against a
# throwaway scratch git "monorepo", with a fake gh/shellcheck/zip/python3
# fixture directory prepended to PATH (see cli/tests/fixtures/release-bin/)
# so `gh`'s answer is deterministic and no test ever makes a real network
# call — a real, unrestricted `git` and `python` are still used so the
# actual git-repo-selection and version-parsing logic under test is real,
# not stubbed. Nothing here ever touches this repo's own git state.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_REPO_SH_SRC="$REPO_ROOT/cli/Release-Repo.sh"
QUALITY_GATE_SRC="$REPO_ROOT/cli/lib/quality-gate.sh"
PAYLOAD_SH_SRC="$REPO_ROOT/cli/lib/skill-payload.sh"
PAYLOAD_PS1_SRC="$REPO_ROOT/cli/lib/skill-payload.ps1"
AGENT_TARGETS_SRC="$REPO_ROOT/cli/agent-targets.json"
FIXTURES_BIN="$SCRIPT_DIR/fixtures/release-bin"

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
        FAIL=$((FAIL+1)); echo "NOT OK - $desc (expected to find [$needle] in output)"
    fi
}

# Fake gh/shellcheck/zip/python3 come first so they shadow anything on the
# real PATH; git and the rest of the real PATH remain unrestricted (real git
# repo-selection logic and a real Python interpreter are exercised for real).
RESTRICTED_PATH="$FIXTURES_BIN:$PATH"

# Builds a fresh scratch "monorepo" at $1 containing exactly what
# Release-Repo.sh needs: a skill directory, cli/lib/*, and the script under
# test itself — so `git rev-parse --show-toplevel` resolves to the scratch
# root and `source "$REPO_ROOT/cli/lib/quality-gate.sh"` finds it there.
build_scratch_repo() {
    local dir="$1"
    rm -rf "$dir"
    mkdir -p "$dir/skills/test-skill" "$dir/cli/lib"
    cat > "$dir/skills/test-skill/SKILL.md" <<'EOF'
---
name: test-skill
description: "fixture skill for Release-Repo.sh integration tests"
metadata:
  version: "1.0.0"
---
Fixture body.
EOF
    cp "$QUALITY_GATE_SRC" "$dir/cli/lib/quality-gate.sh"
    cp "$PAYLOAD_SH_SRC" "$dir/cli/lib/skill-payload.sh"
    cp "$PAYLOAD_PS1_SRC" "$dir/cli/lib/skill-payload.ps1"
    cp "$AGENT_TARGETS_SRC" "$dir/cli/agent-targets.json"
    cp "$RELEASE_REPO_SH_SRC" "$dir/cli/Release-Repo.sh"

    (
        cd "$dir" || exit 1
        git init -q
        git checkout -q -b main 2>/dev/null || git branch -q -m main
        git config user.email "release-repo-test@example.com"
        git config user.name "Release Repo Test"
        git add -A
        git commit -q -m "scratch repo init"
    )
}

# ---------------------------------------------------------------------------
# Scenario (Phase 1.3): an extra `upstream` remote misconfiguration causes
# `gh` to resolve a different base repo than `origin` — D6 preflight MUST
# abort before any tag or push, with no tag created (design Threat Matrix:
# "Git repository selection" + "Push state" rows).
# ---------------------------------------------------------------------------
SCRATCH_A="$(mktemp -d)/monorepo"
build_scratch_repo "$SCRATCH_A"

(
    cd "$SCRATCH_A" || exit 1
    git remote add origin "https://github.com/hjagar/hjagar-skills.git"
    # The misconfiguration under test: an extra `upstream` remote pointing
    # elsewhere. The fake gh (mirroring real gh's own behavior) prefers
    # `upstream` over `origin` when resolving the base repo.
    git remote add upstream "https://github.com/someone-else/other-repo.git"
)

OUTPUT_A="$(
    cd "$SCRATCH_A" || exit 1
    PATH="$RESTRICTED_PATH" HOME="$(mktemp -d)" \
        bash cli/Release-Repo.sh --skill test-skill patch <<< "y" 2>&1
)"
STATUS_A=$?

assert_status "extra upstream remote: Release-Repo.sh exits non-zero" "1" "$STATUS_A"
assert_contains "extra upstream remote: preflight names the mismatch" "publish target mismatch" "$OUTPUT_A"
assert_contains "extra upstream remote: error names the wrongly-resolved repo" "someone-else/other-repo" "$OUTPUT_A"
assert_contains "extra upstream remote: error names the expected repo" "hjagar/hjagar-skills" "$OUTPUT_A"

TAG_COUNT_A="$(cd "$SCRATCH_A" && git tag -l | wc -l | tr -d ' ')"
assert_status "extra upstream remote: no git tag was created" "0" "$TAG_COUNT_A"

# ---------------------------------------------------------------------------
# Scenario (Phase 4.1 regression guard): matching publish target — preflight
# passes and the normal tag+push+release flow completes. Proves D6 does not
# break the happy path.
# ---------------------------------------------------------------------------
SCRATCH_B="$(mktemp -d)/monorepo"
build_scratch_repo "$SCRATCH_B"
BARE_ORIGIN="$(mktemp -d)/origin.git"
git init -q --bare "$BARE_ORIGIN"

(
    cd "$SCRATCH_B" || exit 1
    git remote add origin "$BARE_ORIGIN"
    git push -q origin main
)

OUTPUT_B="$(
    cd "$SCRATCH_B" || exit 1
    PATH="$RESTRICTED_PATH" HOME="$(mktemp -d)" FAKE_REPO_VIEW_RESULT="hjagar/hjagar-skills" \
        bash cli/Release-Repo.sh --skill test-skill patch <<< "y" 2>&1
)"
STATUS_B=$?

assert_status "matching publish target: Release-Repo.sh succeeds end-to-end" "0" "$STATUS_B"
assert_contains "matching publish target: publish target confirmed message shown" \
    "Publish target confirmed: hjagar/hjagar-skills" "$OUTPUT_B"
assert_contains "matching publish target: reaches the final Done message" \
    "Done. Release test-skill-v1.0.1 published." "$OUTPUT_B"

TAG_LIST_B="$(cd "$SCRATCH_B" && git tag -l)"
assert_contains "matching publish target: tag was created" "test-skill-v1.0.1" "$TAG_LIST_B"

# ---------------------------------------------------------------------------
# Scenario (Phase 1.3, triangulation): gh cannot resolve any repo at all
# (auth/network failure) — must also abort before tag/push, with a distinct,
# named error (not silently treated as a match).
# ---------------------------------------------------------------------------
SCRATCH_C="$(mktemp -d)/monorepo"
build_scratch_repo "$SCRATCH_C"

(
    cd "$SCRATCH_C" || exit 1
    git remote add origin "https://github.com/hjagar/hjagar-skills.git"
)

OUTPUT_C="$(
    cd "$SCRATCH_C" || exit 1
    PATH="$RESTRICTED_PATH" HOME="$(mktemp -d)" FAKE_REPO_VIEW_EMPTY="1" \
        bash cli/Release-Repo.sh --skill test-skill patch <<< "y" 2>&1
)"
STATUS_C=$?

assert_status "gh cannot resolve any repo: Release-Repo.sh exits non-zero" "1" "$STATUS_C"
assert_contains "gh cannot resolve any repo: distinct error explains the cause" \
    "could not resolve the publish target repo" "$OUTPUT_C"

TAG_COUNT_C="$(cd "$SCRATCH_C" && git tag -l | wc -l | tr -d ' ')"
assert_status "gh cannot resolve any repo: no git tag was created" "0" "$TAG_COUNT_C"

echo ""
echo "release-repo-integration: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
