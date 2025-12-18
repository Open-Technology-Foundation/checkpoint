#!/usr/bin/env bash
# run_single_test.sh - Run a single BATS test by name pattern
#
# Usage: ./run_single_test.sh "test name pattern"
#
# Examples:
#   ./run_single_test.sh "basic backup creation"
#   ./run_single_test.sh "restore"
#
# Requires: bats (https://github.com/bats-core/bats-core)

set -euo pipefail

# Verify BATS is installed
if ! command -v bats >/dev/null 2>&1; then
  echo "Error: BATS is not installed."
  echo "Install: https://github.com/bats-core/bats-core#installation"
  exit 1
fi

# Check arguments
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <test_name_pattern>"
  echo "Example: $0 \"basic backup creation\""
  exit 1
fi

# Get directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run matching tests across all suites
bats "$SCRIPT_DIR"/*.bats -f "$1"

echo "Test completed!"

#fin
