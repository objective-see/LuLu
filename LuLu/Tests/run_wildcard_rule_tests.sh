#!/bin/bash

#
# run_wildcard_rule_tests.sh
# Script to compile and run wildcard rule tests
#
# note: compiles against Shared/WildcardPath.m, so this tests the real implementation
#

echo "🚀 Building and running wildcard rule tests..."
echo "=============================================="

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/../Shared" && pwd)"
TEST_FILE="$SCRIPT_DIR/test_wildcard_rules.m"
TEST_BINARY="$SCRIPT_DIR/test_wildcard_rules"

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo "❌ Error: Test file not found at $TEST_FILE"
    exit 1
fi

# Check if implementation exists
if [ ! -f "$SHARED_DIR/WildcardPath.m" ]; then
    echo "❌ Error: Implementation not found at $SHARED_DIR/WildcardPath.m"
    exit 1
fi

echo "📁 Test directory: $SCRIPT_DIR"
echo "📄 Test file: $TEST_FILE"
echo "📄 Under test: $SHARED_DIR/WildcardPath.m"

# Compile the test
echo ""
echo "🔨 Compiling test..."
clang -fmodules -framework Foundation \
      -I "$SHARED_DIR" \
      -o "$TEST_BINARY" \
      "$SHARED_DIR/WildcardPath.m" \
      "$TEST_FILE"

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
