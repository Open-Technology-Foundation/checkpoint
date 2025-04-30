#!/usr/bin/env bash
set -euo pipefail

# This script runs a single BATS test for the checkpoint script

# Check if BATS is installed
if ! command -v bats >/dev/null 2>&1; then
  echo "Error: BATS is not installed. Please install it to run the tests."
  echo "Installation: https://github.com/bats-core/bats-core#installation"
  exit 1
fi

# Check if a test name was provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 <test_name>"
  echo "Example: $0 \"basic backup creation\""
  exit 1
fi

# Determine the directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Run the specified test
bats "$SCRIPT_DIR"/*.bats -f "$1"

# Print success message
echo "Test completed!"