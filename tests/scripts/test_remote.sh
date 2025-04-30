#\!/usr/bin/env bash
set -euo pipefail

# Test script for remote backup functionality
# This script simulates a remote backup environment for testing purposes

# Create test directories
TEST_DIR="/tmp/checkpoint-remote-test"
mkdir -p "$TEST_DIR/source" "$TEST_DIR/remote"

# Create some test files
echo "Test file 1" > "$TEST_DIR/source/file1.txt"
echo "Test file 2" > "$TEST_DIR/source/file2.txt"
mkdir -p "$TEST_DIR/source/subdir"
echo "Subdir file" > "$TEST_DIR/source/subdir/file3.txt"

# Create excluded files/dirs
mkdir -p "$TEST_DIR/source/tmp"
echo "Temp file" > "$TEST_DIR/source/tmp/temp.txt"
echo "Backup file" > "$TEST_DIR/source/file1.txt~"

echo "Test environment set up at $TEST_DIR"
echo 
echo "To test remote backup:"
echo "  ./checkpoint --remote user@okusi0:$TEST_DIR/remote $TEST_DIR/source"
echo
echo "To list remote backups:"
echo "  ./checkpoint --remote user@okusi0:$TEST_DIR/remote --list"
echo
echo "To restore from remote backup:"
echo "  ./checkpoint --remote user@okusi0:$TEST_DIR/remote --restore --to $TEST_DIR/restored"
echo
echo "To clean up test environment:"
echo "  rm -rf $TEST_DIR"
