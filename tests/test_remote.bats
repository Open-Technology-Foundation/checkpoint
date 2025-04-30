#!/usr/bin/env bats
# Test suite for remote functionality of checkpoint script
# This uses mock functions to simulate SSH and rsync operations
# for safer testing without actual remote connections

load test_helper

setup() {
  setup_test_directory
  # Mock directory for SSH logs
  mkdir -p "$TEST_TEMP_DIR/ssh_logs"
  export SSH_LOG_FILE="$TEST_TEMP_DIR/ssh_logs/ssh_calls.log"
  export RSYNC_LOG_FILE="$TEST_TEMP_DIR/ssh_logs/rsync_calls.log"
  
  # Create test files
  mkdir -p "$TEST_TEMP_DIR/source"
  echo "test file content" > "$TEST_TEMP_DIR/source/test.txt"
  mkdir -p "$TEST_TEMP_DIR/source/subdir"
  echo "subdir file" > "$TEST_TEMP_DIR/source/subdir/subfile.txt"
}

teardown() {
  teardown_test_directory
}

# Mock SSH function that logs calls instead of executing them
ssh() {
  echo "SSH MOCK CALLED: $*" >> "$SSH_LOG_FILE"
  
  # Parse arguments to simulate behavior
  local host_found=0
  local test_cmd=""
  
  for arg in "$@"; do
    if [[ "$arg" == *"@"* && "$host_found" -eq 0 ]]; then
      host_found=1
      continue
    fi
    
    if [[ "$host_found" -eq 1 ]]; then
      if [[ "$arg" == "--" ]]; then
        continue
      fi
      test_cmd="$test_cmd $arg"
    fi
  done
  
  # Simulate behavior for certain commands
  if [[ "$test_cmd" == *"test -d"* ]]; then
    if [[ "$test_cmd" == *"not_found"* ]]; then
      return 1
    else
      return 0
    fi
  fi
  
  if [[ "$test_cmd" == *"find"* && "$test_cmd" == *"not_found"* ]]; then
    echo "" # Simulate no matches found
    return 0
  fi
  
  if [[ "$test_cmd" == *"find"* ]]; then
    echo "/remote/path/20250401_120000_found" # Simulate found checkpoint
    return 0
  fi
  
  return 0
}

# Mock rsync function
rsync() {
  echo "RSYNC MOCK CALLED: $*" >> "$RSYNC_LOG_FILE"
  
  # Simulate failure for specific test cases
  if [[ "$*" == *"simulate_failure"* ]]; then
    return 1
  fi
  
  return 0
}

# Export the mock functions
export -f ssh rsync

@test "remote: parse_remote function validates input correctly" {
  # Valid remote spec
  run "$SCRIPT_PATH" --remote "user@host:/valid/path" --list
  
  # Remote path with directory traversal should fail
  run "$SCRIPT_PATH" --remote "user@host:/path/../etc/passwd" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot contain directory traversal"* ]]
  
  # Remote path with invalid characters should fail
  run "$SCRIPT_PATH" --remote "user@host:/path/with;semicolon" --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid characters"* ]]
}

@test "remote: create_backup uses secure SSH options" {
  # Clear log files
  > "$SSH_LOG_FILE"
  > "$RSYNC_LOG_FILE"
  
  # Run backup with remote option
  run "$SCRIPT_PATH" --remote "user@host:/remote/path" "$TEST_TEMP_DIR/source"
  
  # Should succeed
  [ "$status" -eq 0 ]
  
  # Check that secure SSH options were used
  grep -q "StrictHostKeyChecking" "$SSH_LOG_FILE"
  grep -q "IdentitiesOnly" "$SSH_LOG_FILE"
  
  # Check the mkdir command format
  grep -q -- "-- mkdir -p /remote/path" "$SSH_LOG_FILE"
  
  # Check that rsync was called with secure options
  grep -q "BatchMode=yes" "$RSYNC_LOG_FILE"
  grep -q "StrictHostKeyChecking" "$RSYNC_LOG_FILE"
}

@test "remote: restore handles non-existent checkpoint correctly" {
  # Clear log files
  > "$SSH_LOG_FILE"
  > "$RSYNC_LOG_FILE"
  
  # Try to restore a non-existent checkpoint
  run "$SCRIPT_PATH" --remote "user@host:/remote/path" --restore --from "not_found"
  
  # Should fail
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
  
  # Check for appropriate test command
  grep -q "test -d" "$SSH_LOG_FILE"
  grep -q "find" "$SSH_LOG_FILE"
}

@test "remote: restore finds partial checkpoint ID matches" {
  # Clear log files
  > "$SSH_LOG_FILE"
  > "$RSYNC_LOG_FILE"
  
  # Create target directory
  mkdir -p "$TEST_TEMP_DIR/target"
  
  # Run restore with partial ID that will match
  run "$SCRIPT_PATH" --remote "user@host:/remote/path" --restore --from "found" --to "$TEST_TEMP_DIR/target"
  
  # Should succeed since the mock will find a matching checkpoint
  [ "$status" -eq 0 ]
  
  # Check for the find command used to locate the checkpoint
  grep -q "find" "$SSH_LOG_FILE"
  
  # Check for secure rsync options
  grep -q "BatchMode=yes" "$RSYNC_LOG_FILE"
  grep -q "StrictHostKeyChecking" "$RSYNC_LOG_FILE"
}

@test "remote: restore handles rsync failure gracefully" {
  # Override rsync to always fail
  rsync() {
    echo "RSYNC MOCK FAILURE" >> "$RSYNC_LOG_FILE"
    return 1
  }
  export -f rsync
  
  # Create target directory
  mkdir -p "$TEST_TEMP_DIR/target"
  
  # Run restore with the failing rsync
  run "$SCRIPT_PATH" --remote "user@host:/remote/path" --restore --to "$TEST_TEMP_DIR/target"
  
  # Should fail
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed"* ]]
}

@test "remote: list handles no backups case correctly" {
  # Override ssh to return "No matching directories"
  ssh() {
    echo "SSH MOCK LIST EMPTY" >> "$SSH_LOG_FILE"
    echo "No matching directories"
    return 0
  }
  export -f ssh
  
  # Run list command
  run "$SCRIPT_PATH" --remote "user@host:/remote/path" --list
  
  # Should succeed but indicate no backups
  [ "$status" -eq 0 ]
  [[ "$output" == *"No backups found"* ]]
}

@test "remote: strict input validation for checkpoint ID" {
  # Try to restore with an invalid checkpoint ID containing injection characters
  run "$SCRIPT_PATH" --remote "user@host:/remote/path" --restore --from "20250401;rm -rf /"
  
  # Should fail due to invalid characters
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid characters"* ]]
}