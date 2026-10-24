#!/bin/bash

#
# run_shortcut_key_layout_tests.sh
# Script to compile and run shortcut key layout regression tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="$SCRIPT_DIR/test_shortcut_key_layouts.m"
TEST_BINARY="$(mktemp "${TMPDIR:-/tmp}/lulu_shortcut_key_layouts.XXXXXX")"

cleanup() {
    rm -f "$TEST_BINARY"
}
trap cleanup EXIT

if [ ! -f "$TEST_FILE" ]; then
    echo "error: test file not found: $TEST_FILE" >&2
    exit 1
fi

clang -framework Foundation \
      -o "$TEST_BINARY" \
      "$TEST_FILE"

"$TEST_BINARY"
