#!/usr/bin/env bash
# Unit tests (Phase 1.5 / 2.1 / 2.2): validate_skill_name + select_highest_tag
# pure functions in install.sh. Sourcing install.sh is safe because it is
# guarded (`if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]`) — no installation side
# effects run.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/../install.sh"

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

# shellcheck disable=SC1090
source "$INSTALL_SH"
# install.sh sets `set -e`; sourcing it propagates that into THIS shell. Turn
# it back off so assertion helpers can inspect non-zero exit codes below
# instead of the test script aborting on the first expected failure.
set +e

# --- validate_skill_name ----------------------------------------------------

validate_skill_name "req-discovery"
assert_status "valid skill name accepted" "0" "$?"

validate_skill_name "us-refinement" >/dev/null 2>&1
assert_status "valid skill name (us-refinement) accepted" "0" "$?"

validate_skill_name "a b" >/dev/null 2>&1
assert_status "space in skill name rejected" "1" "$?"

validate_skill_name "../x" >/dev/null 2>&1
assert_status "path traversal skill name rejected" "1" "$?"

validate_skill_name '$(id)' >/dev/null 2>&1
assert_status "command substitution skill name rejected" "1" "$?"

validate_skill_name "-leading-dash" >/dev/null 2>&1
assert_status "leading-dash skill name rejected" "1" "$?"

# --- select_highest_tag (pure — prefix boundary + 2-digit-safe semver) -----

TAGS_1=$'req-discovery-v1.0.0\nreq-discovery-v1.10.0\nreq-discovery-v1.9.0\nus-refinement-v2.0.0\nus-refinement-x-v9.9.9'

RESULT=$(select_highest_tag "req-discovery" "$TAGS_1")
assert_eq "2-digit-safe semver ordering: v1.10.0 beats v1.9.0" "req-discovery-v1.10.0" "$RESULT"

RESULT=$(select_highest_tag "us-refinement" "$TAGS_1")
assert_eq "prefix boundary: us-refinement-v* excludes us-refinement-x-v*" "us-refinement-v2.0.0" "$RESULT"

RESULT=$(select_highest_tag "res-onboarding" "$TAGS_1")
assert_eq "no matching tag returns empty" "" "$RESULT"

TAGS_2=$'req-discovery-v0.1.0\nreq-discovery-v0.2.0\nreq-discovery-v0.10.0'
RESULT=$(select_highest_tag "req-discovery" "$TAGS_2")
assert_eq "triangulation: another skill/version set still 2-digit-safe" "req-discovery-v0.10.0" "$RESULT"

# --- extract_skill_names_from_tags (pure, US-17 D8 discover-all) -----------

DISCOVERY_TAGS=$'us-refinement-v1.0.0\nreq-discovery-v1.0.0\nreq-discovery-v1.10.0\ntc-generator-v2.0.0\nus-refinement-x-v9.9.9'
RESULT=$(extract_skill_names_from_tags "$DISCOVERY_TAGS")
assert_eq "discover-all extracts distinct skill names, deduped and sorted" \
    "$(printf 'req-discovery\ntc-generator\nus-refinement\nus-refinement-x')" "$RESULT"

RESULT=$(extract_skill_names_from_tags "")
assert_eq "discover-all on empty tag list returns empty" "" "$RESULT"

RESULT=$(extract_skill_names_from_tags $'not-a-tag\nrandom-text')
assert_eq "discover-all ignores tags not matching <skill>-vMAJOR.MINOR.PATCH" "" "$RESULT"

echo ""
echo "install-unit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
