#!/bin/bash

# Interactive test runner for LuLu test suites
# No automatic execution - prompts user for which tests to run

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSIVE_MODE_TEST="$SCRIPT_DIR/test_passive_mode_improvements.m"
MEMORY_LEAK_TEST="$SCRIPT_DIR/test_memory_leak_fixes.m"

echo ""
echo "============================================"
echo "  LuLu Test Suite Runner"
echo "============================================"
echo ""
echo "Select tests to run:"
echo ""
echo "  1) Run all tests (19 tests total)"
echo "  2) Run passive mode tests only (9 tests)"
echo "  3) Run memory leak tests only (10 tests)"
echo "  4) Exit"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo ""
        echo "Running all tests..."
        echo ""

        # Build and run passive mode tests
        echo "Building passive mode tests..."
        clang -framework Foundation -framework NetworkExtension \
            -Wno-objc-missing-property-synthesis \
            -Wno-incomplete-implementation \
            -o /tmp/test_passive_mode \
            "$PASSIVE_MODE_TEST"

        if [ $? -ne 0 ]; then
            echo "[ERROR] Passive mode test build failed"
            exit 1
        fi

        /tmp/test_passive_mode
        PASSIVE_RESULT=$?
        rm -f /tmp/test_passive_mode

        # Build and run memory leak tests
        echo ""
        echo "Building memory leak tests..."
        clang -framework Foundation -framework NetworkExtension \
            -lbsm \
            -Wno-objc-missing-property-synthesis \
            -Wno-incomplete-implementation \
            -Wno-objc-missing-super-calls \
            -o /tmp/test_memory_leak \
            "$MEMORY_LEAK_TEST"

        if [ $? -ne 0 ]; then
            echo "[ERROR] Memory leak test build failed"
            exit 1
        fi

        /tmp/test_memory_leak
        MEMORY_RESULT=$?
        rm -f /tmp/test_memory_leak

        # Check combined results
        if [ $PASSIVE_RESULT -eq 0 ] && [ $MEMORY_RESULT -eq 0 ]; then
            echo ""
            echo "============================================"
            echo "  ALL TESTS PASSED (19/19)"
            echo "============================================"
            exit 0
        else
            echo ""
            echo "============================================"
            echo "  SOME TESTS FAILED"
            echo "============================================"
            exit 1
        fi
        ;;
    2)
        echo ""
        echo "Building passive mode tests..."
        clang -framework Foundation -framework NetworkExtension \
            -Wno-objc-missing-property-synthesis \
            -Wno-incomplete-implementation \
            -o /tmp/test_passive_mode \
            "$PASSIVE_MODE_TEST"

        if [ $? -ne 0 ]; then
            echo "[ERROR] Build failed"
            exit 1
        fi

        echo "[BUILD OK]"
        echo ""
        echo "Running tests..."
        echo ""

        /tmp/test_passive_mode
        TEST_RESULT=$?

        rm -f /tmp/test_passive_mode
        exit $TEST_RESULT
        ;;
    3)
        echo ""
        echo "Building memory leak tests..."
        clang -framework Foundation -framework NetworkExtension \
            -lbsm \
            -Wno-objc-missing-property-synthesis \
            -Wno-incomplete-implementation \
            -Wno-objc-missing-super-calls \
            -o /tmp/test_memory_leak \
            "$MEMORY_LEAK_TEST"

        if [ $? -ne 0 ]; then
            echo "[ERROR] Build failed"
            exit 1
        fi

        echo "[BUILD OK]"
        echo ""
        echo "Running tests..."
        echo ""

        /tmp/test_memory_leak
        TEST_RESULT=$?

        rm -f /tmp/test_memory_leak
        exit $TEST_RESULT
        ;;
    4)
        echo "Exiting"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
