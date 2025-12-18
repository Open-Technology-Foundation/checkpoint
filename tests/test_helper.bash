#!/usr/bin/env bash
# Test helper functions for checkpoint BATS tests

# Get the script path (parent directory of the test directory)
SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/checkpoint"

# Set up temporary test directory
setup_test_directory() {
  # Create a temporary directory specific to this test run
  TEST_TEMP_DIR=$(mktemp -d)
  export TEST_TEMP_DIR
  
  # Set the PATH to include test directory for mock binaries
  PATH="$TEST_TEMP_DIR:$PATH"
  export PATH
}

# Clean up test directory
teardown_test_directory() {
  # Remove the temporary directory created for this test
  rm -rf "$TEST_TEMP_DIR"
}

# Export variables and functions
export SCRIPT_DIR
export SCRIPT_PATH
#fin
