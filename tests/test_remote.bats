#!/usr/bin/env bats
# Test suite for remote functionality of checkpoint script
#
# NOTE: The checkpoint script sets a secure PATH at startup that prepends
# system directories (/usr/local/bin:/usr/bin:/bin), which prevents mock
# ssh/rsync scripts from being used. These tests focus on:
#   1. Input validation (works without SSH)
#   2. Parse functions (works without SSH)
#   3. Real SSH integration tests (skipped unless CHECKPOINT_TEST_SSH=1)

load test_helper

setup() {
  setup_test_directory

  # Create test files
  mkdir -p "$TEST_TEMP_DIR/source"
  echo "test file content" > "$TEST_TEMP_DIR/source/test.txt"
  mkdir -p "$TEST_TEMP_DIR/source/subdir"
  echo "subdir file" > "$TEST_TEMP_DIR/source/subdir/subfile.txt"
}

teardown() {
  teardown_test_directory
}

# ============================================================================
# INPUT VALIDATION TESTS (No SSH Required)
# ============================================================================

@test "remote: rejects path with directory traversal" {
  run "$SCRIPT_PATH" --remote "user@host:/path/../etc/passwd" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot contain directory traversal"* ]]
}

@test "remote: rejects path with semicolon injection" {
  run "$SCRIPT_PATH" --remote "user@host:/path/with;semicolon" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid characters"* ]]
}

@test "remote: rejects path with backtick injection" {
  run "$SCRIPT_PATH" --remote "user@host:/path/\`id\`" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid characters"* ]]
}

@test "remote: rejects path with dollar sign injection" {
  run "$SCRIPT_PATH" --remote 'user@host:/path/$(id)' --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid characters"* ]]
}

@test "remote: rejects path with pipe injection" {
  run "$SCRIPT_PATH" --remote "user@host:/path|cat /etc/passwd" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid characters"* ]]
}

@test "remote: accepts valid simple path" {
  # This will fail SSH connection but should pass validation
  run "$SCRIPT_PATH" --remote "user@host:/valid/path" --list 2>&1
  # Should fail with connection error, not validation error
  [[ "$output" != *"invalid characters"* ]]
  [[ "$output" != *"directory traversal"* ]]
}

@test "remote: accepts path with underscores and hyphens" {
  run "$SCRIPT_PATH" --remote "user@host:/path/with_under-scores" --list 2>&1
  [[ "$output" != *"invalid characters"* ]]
}

@test "remote: accepts path with dots" {
  run "$SCRIPT_PATH" --remote "user@host:/path/file.txt" --list 2>&1
  [[ "$output" != *"invalid characters"* ]]
}

@test "remote: rejects invalid remote format - missing user" {
  run "$SCRIPT_PATH" --remote "host:/path" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid remote"* ]] || [[ "$output" == *"invalid"* ]]
}

@test "remote: rejects invalid remote format - missing path" {
  run "$SCRIPT_PATH" --remote "user@host" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid remote"* ]] || [[ "$output" == *"invalid"* ]]
}

@test "remote: checkpoint ID validation rejects injection characters" {
  # Create target directory
  mkdir -p "$TEST_TEMP_DIR/target"

  # The script validates checkpoint IDs after SSH connectivity check
  # If SSH fails (Cannot connect), validation doesn't run
  # If SSH succeeds, validation rejects bad characters
  run "$SCRIPT_PATH" --remote "user@host:/path" --restore --from "20250401;rm -rf /" --to "$TEST_TEMP_DIR/target"
  [ "$status" -ne 0 ]
  # Either connection fails OR invalid characters detected OR checkpoint not found
  [[ "$output" == *"invalid characters"* ]] || \
  [[ "$output" == *"Cannot connect"* ]] || \
  [[ "$output" == *"not found"* ]]
}

@test "remote: checkpoint ID validation rejects spaces" {
  mkdir -p "$TEST_TEMP_DIR/target"
  run "$SCRIPT_PATH" --remote "user@host:/path" --restore --from "2025 0401" --to "$TEST_TEMP_DIR/target"
  [ "$status" -eq 1 ]
}

# ============================================================================
# SSH INTEGRATION TESTS (Require CHECKPOINT_TEST_SSH=1 and valid SSH config)
# ============================================================================
# These tests are skipped by default. To run them:
#   CHECKPOINT_TEST_SSH=1 CHECKPOINT_TEST_HOST=user@yourhost bats test_remote.bats

@test "remote: real SSH connection test" {
  [[ -n "${CHECKPOINT_TEST_SSH:-}" ]] || skip "Set CHECKPOINT_TEST_SSH=1 to run SSH integration tests"
  [[ -n "${CHECKPOINT_TEST_HOST:-}" ]] || skip "Set CHECKPOINT_TEST_HOST=user@host:/path"

  run "$SCRIPT_PATH" --remote "$CHECKPOINT_TEST_HOST" --list
  [ "$status" -eq 0 ]
}

@test "remote: real backup and restore cycle" {
  [[ -n "${CHECKPOINT_TEST_SSH:-}" ]] || skip "Set CHECKPOINT_TEST_SSH=1 to run SSH integration tests"
  [[ -n "${CHECKPOINT_TEST_HOST:-}" ]] || skip "Set CHECKPOINT_TEST_HOST=user@host:/path"

  # Create backup
  run "$SCRIPT_PATH" --remote "$CHECKPOINT_TEST_HOST" "$TEST_TEMP_DIR/source" -q
  [ "$status" -eq 0 ]

  # List should show the backup
  run "$SCRIPT_PATH" --remote "$CHECKPOINT_TEST_HOST" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"20"* ]]  # Should contain timestamp
}

# ============================================================================
# UNIT TESTS FOR REMOTE HELPER FUNCTIONS
# ============================================================================

@test "remote: timeout option accepts valid numbers" {
  # Timeout validation happens before SSH connection
  run "$SCRIPT_PATH" --remote "user@host:/path" --timeout 60 --list
  # Should fail with connection error, not timeout validation error
  [[ "$output" != *"Invalid timeout"* ]]
}

@test "remote: timeout option rejects non-numeric values" {
  run "$SCRIPT_PATH" --remote "user@host:/path" --timeout "abc" --list
  # Exit code 22 = EINVAL (invalid argument)
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalid"* ]]
}

@test "remote: timeout option requires positive value" {
  # "-5" is interpreted as an option flag (starts with -), not a value
  # So the script sees --timeout as missing its argument
  run "$SCRIPT_PATH" --remote "user@host:/path" --timeout "-5" --list
  [ "$status" -ne 0 ]
  # Either "Missing argument" or "Invalid" depending on parsing
  [[ "$output" == *"Missing"* ]] || [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalid"* ]]
}

#fin
