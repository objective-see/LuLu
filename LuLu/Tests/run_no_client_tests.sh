#!/bin/bash

#
# Regression checks for the no-client fallback policy.
# These checks intentionally read the production implementation so they fail if
# the fallback starts persisting rules or moves ahead of explicit policy checks.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/../Extension/FilterDataProvider.m"
TEST_FILE="$SCRIPT_DIR/test_no_client_fallback.m"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lulu-no-client-tests.XXXXXX")"

cleanup()
{
    rm -rf "$BUILD_DIR"
}

trap cleanup EXIT

tests_passed=0
tests_total=0

pass()
{
    tests_passed=$((tests_passed + 1))
}

check_contains()
{
    tests_total=$((tests_total + 1))
    if grep -Fq "$2" <<< "$1"; then
        pass
    else
        echo "FAIL: $3"
    fi
}

check_not_contains()
{
    tests_total=$((tests_total + 1))
    if ! grep -Fq "$2" <<< "$1"; then
        pass
    else
        echo "FAIL: $3"
    fi
}

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "FAIL: production source not found at $SOURCE_FILE"
    exit 1
fi

if [[ ! -f "$TEST_FILE" ]]; then
    echo "FAIL: test source not found at $TEST_FILE"
    exit 1
fi

# Compile the production extension sources into an isolated harness and invoke
# the real no-client helper with a Rules test double. No system extension is
# installed and no live firewall state is read or changed.
extension_sources=()
for extension_source in "$SCRIPT_DIR"/../Extension/*.m; do
    if [[ "$(basename "$extension_source")" != "main.m" ]]; then
        extension_sources+=("$extension_source")
    fi
done

xcrun clang \
    -fobjc-arc \
    -fblocks \
    -fmodules \
    -Werror \
    -Wno-deprecated-declarations \
    -Wno-gnu-folding-constant \
    -Wno-nonnull \
    -Wno-nonportable-include-path \
    -Wno-nullability-completeness \
    -Wno-shadow-ivar \
    -I "$SCRIPT_DIR/../App" \
    -I "$SCRIPT_DIR/../Extension" \
    -I "$SCRIPT_DIR/../Shared" \
    -framework AppKit \
    -framework Foundation \
    -framework NetworkExtension \
    -framework Security \
    -framework SystemConfiguration \
    -framework SystemExtensions \
    -lbsm \
    -o "$BUILD_DIR/test_no_client_fallback" \
    "$TEST_FILE" \
    "${extension_sources[@]}" \
    "$SCRIPT_DIR/../Shared/Rule.m" \
    "$SCRIPT_DIR/../Shared/signing.m" \
    "$SCRIPT_DIR/../Shared/utilities.m"

"$BUILD_DIR/test_no_client_fallback"

allow_no_client="$(sed -n '/-(FlowVerdict)allowNoClient/,/^}/p' "$SOURCE_FILE")"
process_event="$(sed -n '/-(FlowVerdict)processEvent:/,/^}/p' "$SOURCE_FILE")"
matching_rule_branch="$(sed -n '/matchingRule = \[rules find:/,/\/\* NO MATCHING RULE FOUND \*\//p' "$SOURCE_FILE")"
passive_branch="$(sed -n '/if(YES == \[preferences.preferences\[PREF_PASSIVE_MODE\] boolValue\])/,/BOOL canAlert/p' "$SOURCE_FILE")"
apple_branch="$(sed -n '/if(YES == \[preferences.preferences\[PREF_ALLOW_APPLE\] boolValue\])/,/\/\/\x27allow installed\x27 check/p' "$SOURCE_FILE")"

check_contains "$allow_no_client" "return kFlowVerdictAllow;" \
    "no-client fallback must allow the current flow"
check_not_contains "$allow_no_client" "[rules add:" \
    "no-client fallback must not add a rule"
check_not_contains "$allow_no_client" "save:YES" \
    "no-client fallback must not save rules"
check_not_contains "$allow_no_client" "RULE_TYPE_PASSIVE" \
    "no-client fallback must not create a passive rule"
check_not_contains "$allow_no_client" "[[Rule alloc] init:" \
    "no-client fallback must not construct a rule"

tests_total=$((tests_total + 1))
fallback_calls="$(grep -Fc "[self allowNoClient]" <<< "$process_event")"
if [[ "$fallback_calls" -eq 3 ]]; then
    pass
else
    echo "FAIL: expected 3 alert-requiring no-client paths, found $fallback_calls"
fi

rule_lookup_line="$(grep -n -m1 'matchingRule = \[rules find:' <<< "$process_event" | cut -d: -f1)"
passive_line="$(grep -n -m1 'PREF_PASSIVE_MODE] boolValue' <<< "$process_event" | cut -d: -f1)"
can_alert_line="$(grep -n -m1 'BOOL canAlert' <<< "$process_event" | cut -d: -f1)"
fallback_line="$(grep -n 'if(NO == canAlert)' <<< "$process_event" | tail -1 | cut -d: -f1)"

tests_total=$((tests_total + 1))
if [[ -n "$rule_lookup_line" && -n "$passive_line" && -n "$can_alert_line" && -n "$fallback_line" ]] &&
   (( rule_lookup_line < passive_line && passive_line < can_alert_line && can_alert_line < fallback_line )); then
    pass
else
    echo "FAIL: explicit-rule, passive-mode, and no-client precedence changed"
fi

check_contains "$process_event" "PREF_BLOCK_MODE" \
    "block mode must remain ahead of the no-client fallback"
check_contains "$process_event" "PREF_USE_BLOCK_LIST" \
    "the block list must remain ahead of the no-client fallback"
check_contains "$process_event" "PREF_USE_ALLOW_LIST" \
    "the allow list must remain ahead of the no-client fallback"
check_contains "$matching_rule_branch" "RULE_STATE_BLOCK" \
    "explicit block rules must remain enforceable"
check_contains "$matching_rule_branch" "verdict = kFlowVerdictBlock" \
    "explicit block rules must retain their block verdict"
check_contains "$passive_branch" "[rules add:" \
    "configured passive-mode rule creation must remain enabled"
check_contains "$passive_branch" "save:YES" \
    "configured passive-mode rules must remain persistent"
check_contains "$passive_branch" "kFlowVerdictAllow" \
    "passive-mode allow behavior must remain available"
check_contains "$passive_branch" "kFlowVerdictBlock" \
    "passive-mode block behavior must remain available"
check_contains "$apple_branch" "RULE_TYPE_APPLE" \
    "intentional Apple allow rules must remain available"
check_contains "$apple_branch" "save:YES" \
    "intentional Apple allow rules must remain persistent"
check_contains "$process_event" "verdict = kFlowVerdictPause;" \
    "a connected client must still pause an unknown flow for an alert"
check_contains "$process_event" "[self alert:(NEFilterSocketFlow*)flow process:process];" \
    "a connected client must still receive an alert for an unknown flow"

tests_total=$((tests_total + 1))
apple_fallback_calls="$(grep -Fc "[self allowNoClient]" <<< "$apple_branch")"
if [[ "$apple_fallback_calls" -eq 2 ]]; then
    pass
else
    echo "FAIL: Apple graylist/non-matching-rule fallback paths changed"
fi

echo "Tests Passed: $tests_passed/$tests_total"

if [[ "$tests_passed" -ne "$tests_total" ]]; then
    exit 1
fi

echo "PASS: no-client flows are allowed without persistent rules"
echo "PASS: explicit, passive-mode, and Apple policy precedence is preserved"
