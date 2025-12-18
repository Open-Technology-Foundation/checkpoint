#!/usr/bin/env bash
# test_helper.bash - Common setup functions for checkpoint BATS tests
#
# This file is sourced by all BATS test files to provide:
#   - SCRIPT_DIR: Directory containing the checkpoint script
#   - SCRIPT_PATH: Full path to the checkpoint script
#   - setup_test_directory(): Create isolated temp directory for test
#   - teardown_test_directory(): Clean up temp directory after test
#
# Usage in test files:
#   load test_helper
#   setup() { setup_test_directory; }
#   teardown() { teardown_test_directory; }

# Locate the checkpoint script (parent of tests directory)
SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/checkpoint"

# setup_test_directory: Create isolated temp directory for a test
# Sets TEST_TEMP_DIR and adds it to PATH for mock binaries
setup_test_directory() {
  TEST_TEMP_DIR=$(mktemp -d)
  export TEST_TEMP_DIR
  PATH="$TEST_TEMP_DIR:$PATH"
  export PATH
}

# teardown_test_directory: Remove the test's temp directory
teardown_test_directory() {
  rm -rf "$TEST_TEMP_DIR"
}

# Export for use in test files
export SCRIPT_DIR
export SCRIPT_PATH

#fin
