#!/usr/bin/env bash
set -euo pipefail

# This script runs the BATS tests for the checkpoint script

# Check if BATS is installed
if ! command -v bats >/dev/null 2>&1; then
  echo "Error: BATS is not installed. Please install it to run the tests."
  echo "Installation: https://github.com/bats-core/bats-core#installation"
  exit 1
fi

# Determine the directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Run all tests
bats "$SCRIPT_DIR"/*.bats

# Print success message
echo "All tests completed!"