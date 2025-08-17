#!/bin/bash

#
# run_passive_mode_tests.sh
# Script to compile and run passive mode improvements tests
#

echo "🚀 Building and running passive mode improvements tests..."
echo "========================================================"

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="$SCRIPT_DIR/test_passive_mode_improvements.m"
TEST_BINARY="$SCRIPT_DIR/test_passive_mode_improvements"

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo "❌ Error: Test file not found at $TEST_FILE"
    exit 1
fi

echo "📁 Test directory: $SCRIPT_DIR"
echo "📄 Test file: $TEST_FILE"

# Compile the test
echo ""
echo "🔨 Compiling test..."
clang -framework Foundation -framework NetworkExtension \
      -o "$TEST_BINARY" \
      "$TEST_FILE" \
      -Wno-objc-missing-property-synthesis \
      -Wno-incomplete-implementation

# Check if compilation succeeded
if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi

echo "✅ Compilation successful!"

# Run the test
echo ""
echo "🧪 Running tests..."
echo "=================="
"$TEST_BINARY"

# Capture test result
TEST_RESULT=$?

# Clean up
echo ""
echo "🧹 Cleaning up..."
rm -f "$TEST_BINARY"

# Report final result
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ All tests completed successfully!"
else
    echo "❌ Tests failed with exit code $TEST_RESULT"
fi

exit $TEST_RESULT
