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

# --- build_agent_paths (US-24 — manifest-driven AGENT_PATHS) ---------------

PAYLOAD_LIB="$SCRIPT_DIR/../lib/skill-payload.sh"
# shellcheck disable=SC1090
source "$PAYLOAD_LIB"

BAP_HOME="$(mktemp -d)"
HOME="$BAP_HOME" build_agent_paths "req-discovery"
BAP_RESULT="$(printf '%s\n' "${AGENT_PATHS[@]}" | sort)"
BAP_EXPECTED="$(printf '%s\n' \
    "$BAP_HOME/.gemini/skills/req-discovery" \
    "$BAP_HOME/.claude/skills/req-discovery" \
    "$BAP_HOME/.config/opencode/skills/req-discovery" \
    "$BAP_HOME/.copilot/skills/req-discovery" \
    "$BAP_HOME/.agents/skills/req-discovery" \
    "$BAP_HOME/.cursor/skills/req-discovery" | sort)"
assert_eq "build_agent_paths produces every manifest-listed directory" "$BAP_EXPECTED" "$BAP_RESULT"

BAP_KIRO_MATCH="$(printf '%s\n' "${AGENT_PATHS[@]}" | grep -c "kiro" || true)"
assert_eq "build_agent_paths excludes the Kiro transform entry (handled separately)" "0" "${BAP_KIRO_MATCH:-0}"

BAP_COUNT="${#AGENT_PATHS[@]}"
assert_eq "build_agent_paths emits exactly the 6 non-transform manifest entries" "6" "$BAP_COUNT"
rm -rf "$BAP_HOME"

# US-24 acceptance scenario 2: "new agent added" — appending one manifest
# entry (no script edits) must make it appear in AGENT_PATHS, with no other
# entry affected.
BAP_MANIFEST_TMP="$(mktemp -d)"
NEW_MANIFEST="$BAP_MANIFEST_TMP/agent-targets.json"
python3 - "$SCRIPT_DIR/../agent-targets.json" "$NEW_MANIFEST" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    data = json.load(f)
data["targets"].append({"id": "newagent", "path_template": ".newagent/skills/{skill_name}"})
with open(dst, "w", encoding="utf-8") as f:
    json.dump(data, f)
PY

mkdir -p "$BAP_MANIFEST_TMP/lib"
cp "$PAYLOAD_LIB" "$BAP_MANIFEST_TMP/lib/skill-payload.sh"
BAP_NEW_HOME="$(mktemp -d)"
(
    # shellcheck disable=SC1090
    source "$BAP_MANIFEST_TMP/lib/skill-payload.sh"
    HOME="$BAP_NEW_HOME" build_agent_paths "req-discovery"
    printf '%s\n' "${AGENT_PATHS[@]}"
) > "$BAP_MANIFEST_TMP/result.txt"
BAP_NEW_COUNT="$(wc -l < "$BAP_MANIFEST_TMP/result.txt" | tr -d ' ')"
BAP_NEW_MATCH="$(grep -c "newagent/skills/req-discovery" "$BAP_MANIFEST_TMP/result.txt" || true)"
assert_eq "new agent added via one manifest line appears with no script edits" "1" "${BAP_NEW_MATCH:-0}"
assert_eq "existing 6 entries are untouched (7 total after the new line)" "7" "$BAP_NEW_COUNT"
rm -rf "$BAP_MANIFEST_TMP" "$BAP_NEW_HOME"

echo ""
echo "install-unit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
