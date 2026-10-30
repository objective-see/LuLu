#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"
mkdir -p "$PROJECT_DIR/work"
TEST_WORK="$(mktemp -d "$PROJECT_DIR/work/strict-rule-format.XXXXXX")"
trap 'rm -rf "$TEST_WORK"' EXIT

clang "$TEST_DIR/strict_process_tree/canary.c" -o "$TEST_WORK/canary"

clang -fobjc-arc -fmodules -fmodules-cache-path="$TEST_WORK/modules" \
    -include Security/Security.h \
    -I "$PROJECT_DIR/LuLu/Shared" -I "$PROJECT_DIR/LuLu/App" \
    -I "$PROJECT_DIR/LuLu/App/3rd-party" \
    -framework Foundation -framework AppKit -framework Security \
    -framework SystemConfiguration -framework Carbon \
    -Wno-shadow-ivar -Wno-deprecated-declarations \
    "$TEST_DIR/test_strict_rule_format.m" \
    "$PROJECT_DIR/LuLu/Shared/Rule.m" "$PROJECT_DIR/LuLu/Shared/utilities.m" \
    "$PROJECT_DIR/LuLu/Shared/signing.m" \
    -o "$TEST_WORK/test_strict_rule_format"
STRICT_RULE_TEST_WORK="$TEST_WORK" "$TEST_WORK/test_strict_rule_format"
