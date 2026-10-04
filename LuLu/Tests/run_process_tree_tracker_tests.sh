#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LULU_DIR="$(cd "$TEST_DIR/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lulu-lineage-tests.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

xcrun clang -fobjc-arc -fblocks -fmodules -fmodules-cache-path="$BUILD_DIR/modules" -Wall -Wextra -Wno-unused-parameter \
    -I "$LULU_DIR/Extension" "$LULU_DIR/Extension/ProcessTreeTracker.m" \
    "$TEST_DIR/test_process_tree_tracker.m" -framework Foundation -lbsm -lEndpointSecurity \
    -o "$BUILD_DIR/tracker-tests"
"$BUILD_DIR/tracker-tests"
