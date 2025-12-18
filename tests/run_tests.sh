#!/usr/bin/env bash
# run_tests.sh - Run all BATS test suites in this directory
#
# Usage: ./run_tests.sh
#
# Requires: bats (https://github.com/bats-core/bats-core)

set -euo pipefail

# Verify BATS is installed
if ! command -v bats >/dev/null 2>&1; then
  echo "Error: BATS is not installed."
  echo "Install: https://github.com/bats-core/bats-core#installation"
  exit 1
fi

# Get directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run all test suites
bats "$SCRIPT_DIR"/*.bats

echo "All tests completed!"

#fin
