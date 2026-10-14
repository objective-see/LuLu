#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LULU_DIR="$(cd "$TEST_DIR/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lulu-strict-tests.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

FLAGS=(-fobjc-arc -fmodules -fmodules-cache-path="$BUILD_DIR/modules" -fblocks -Wno-deprecated-declarations -Wno-incomplete-implementation -Wno-shadow-ivar -Wno-nonportable-include-path -Wno-gnu-folding-constant
    -I"$LULU_DIR/Shared" -I"$LULU_DIR/Extension" -I"$LULU_DIR/App"
    -I"$TEST_DIR/strict_process_tree")

# Matching helpers are the production helpers. Only live process/session probes are renamed.
xcrun clang "${FLAGS[@]}" -DisAlive=acceptanceLiveIsAlive -DgetConsoleUser=acceptanceLiveConsoleUser \
    -c "$LULU_DIR/Shared/utilities.m" -o "$BUILD_DIR/utilities.o"
xcrun clang "${FLAGS[@]}" \
    "$LULU_DIR/Shared/Rule.m" "$LULU_DIR/Extension/Rules.m" \
    "$LULU_DIR/Extension/ProcessTreeTracker.m" "$LULU_DIR/Extension/FilterDataProvider.m" \
    "$LULU_DIR/Extension/XPCDaemon.m" \
    "$TEST_DIR/strict_process_tree/Support.m" "$TEST_DIR/strict_process_tree/Acceptance.m" \
    "$BUILD_DIR/utilities.o" \
    -framework Foundation -framework AppKit -framework NetworkExtension -framework Security \
    -framework Carbon -framework SystemConfiguration -framework ServiceManagement -lbsm -lEndpointSecurity \
    -o "$BUILD_DIR/acceptance"
"$BUILD_DIR/acceptance"
