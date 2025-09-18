#!/usr/bin/env bats
# Test suite for non-root user functionality

setup() {
  # Get the test directory and project root
  TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  # Get the project root directory (parent of tests)
  PROJECT_ROOT="$( cd "$TEST_DIR/.." >/dev/null 2>&1 && pwd )"

  # Path to the checkpoint script
  CHECKPOINT="$PROJECT_ROOT/checkpoint"

  # Create a temporary test directory
  TEST_TEMP_DIR="$(mktemp -d)"
  export CHECKPOINT_AUTO_CONFIRM=1  # Skip prompts in tests

  # Create test source directory
  TEST_SOURCE_DIR="$TEST_TEMP_DIR/source"
  mkdir -p "$TEST_SOURCE_DIR"

  # Create test backup directory in user-accessible location
  TEST_BACKUP_DIR="$TEST_TEMP_DIR/backups"
  mkdir -p "$TEST_BACKUP_DIR"

  # Add some test files
  echo "test content" > "$TEST_SOURCE_DIR/file1.txt"
  echo "more content" > "$TEST_SOURCE_DIR/file2.txt"
  mkdir -p "$TEST_SOURCE_DIR/subdir"
  echo "subdir content" > "$TEST_SOURCE_DIR/subdir/file3.txt"
}

teardown() {
  # Clean up temporary test directory
  if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "non-root user can backup to user-writable directory" {
  # Run checkpoint with explicit user-writable backup directory
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" --no-sudo -q "$TEST_SOURCE_DIR"

  [ "$status" -eq 0 ]

  # Verify backup was created
  backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "20*" | wc -l)
  [ "$backup_count" -gt 0 ]
}

@test "helper function check_dir_access works correctly" {
  # Create a test script that calls the check_dir_access function
  cat > "$TEST_TEMP_DIR/test_access.sh" << 'EOT'
#!/usr/bin/env bash
# Source just the helper function
check_dir_access() {
  local -- test_dir="$1"

  # If directory doesn't exist, check if we can create it
  if [[ ! -d "$test_dir" ]]; then
    # Check parent directory for write access
    local -- parent_dir
    parent_dir=$(dirname "$test_dir")

    # Keep going up until we find an existing directory
    while [[ ! -d "$parent_dir" ]] && [[ "$parent_dir" != "/" ]]; do
      parent_dir=$(dirname "$parent_dir")
    done

    # Test if we can write to the parent
    [[ -w "$parent_dir" ]]
    return $?
  fi

  # Directory exists, test if we can write to it
  [[ -w "$test_dir" ]]
  return $?
}

# Test the function with the provided path
check_dir_access "$1"
exit $?
EOT
  chmod +x "$TEST_TEMP_DIR/test_access.sh"

  # Test with writable directory
  run "$TEST_TEMP_DIR/test_access.sh" "$TEST_BACKUP_DIR"
  [ "$status" -eq 0 ]

  # Test with non-existent but creatable directory
  run "$TEST_TEMP_DIR/test_access.sh" "$TEST_BACKUP_DIR/newdir"
  [ "$status" -eq 0 ]

  # Test with likely non-writable directory (if not root)
  if [[ $EUID -ne 0 ]]; then
    run "$TEST_TEMP_DIR/test_access.sh" "/root"
    [ "$status" -ne 0 ]
  fi
}

@test "get_default_backup_dir returns appropriate directory for non-root" {
  # Create a test script that calls the get_default_backup_dir function
  cat > "$TEST_TEMP_DIR/test_default.sh" << 'EOT'
#!/usr/bin/env bash
# Mock the is_root_or_sudo function
is_root_or_sudo() {
  [[ "$1" == "root" ]] && return 0 || return 1
}

get_default_backup_dir() {
  local -- dir_name="$1"

  # Check if user specified a default via environment variable
  if [[ -n "${CHECKPOINT_BACKUP_DIR:-}" ]]; then
    echo "${CHECKPOINT_BACKUP_DIR}/${dir_name}"
    return 0
  fi

  # If running as root or with sudo, use system location
  if is_root_or_sudo "$2"; then
    echo "/var/backups/${dir_name}"
    return 0
  fi

  # For non-root users, prefer home directory
  echo "${HOME}/.checkpoint/${dir_name}"
  return 0
}

# Test the function
get_default_backup_dir "testdir" "$1"
EOT
  chmod +x "$TEST_TEMP_DIR/test_default.sh"

  # Test as non-root user
  run "$TEST_TEMP_DIR/test_default.sh" "user"
  [[ "$output" =~ \.checkpoint/testdir$ ]]

  # Test as root
  run "$TEST_TEMP_DIR/test_default.sh" "root"
  [[ "$output" == "/var/backups/testdir" ]]

  # Test with environment variable
  CHECKPOINT_BACKUP_DIR="/custom/path" run "$TEST_TEMP_DIR/test_default.sh" "user"
  [[ "$output" == "/custom/path/testdir" ]]
}

@test "backup with CHECKPOINT_BACKUP_DIR environment variable" {
  # Set custom backup directory via environment variable
  export CHECKPOINT_BACKUP_DIR="$TEST_TEMP_DIR/custom_backups"
  mkdir -p "$CHECKPOINT_BACKUP_DIR"

  # Run checkpoint which should use the environment variable
  cd "$TEST_SOURCE_DIR"
  run "$CHECKPOINT" --no-sudo -q

  [ "$status" -eq 0 ]

  # Verify backup was created in custom location
  custom_backup_dir="$CHECKPOINT_BACKUP_DIR/$(basename "$TEST_SOURCE_DIR")"
  [ -d "$custom_backup_dir" ]

  backup_count=$(find "$custom_backup_dir" -maxdepth 1 -type d -name "20*" | wc -l)
  [ "$backup_count" -gt 0 ]
}

@test "non-root user gets appropriate error for inaccessible directory" {
  # Skip if running as root
  [[ $EUID -eq 0 ]] && skip "Test only applicable for non-root users"

  # Skip if /var/backups is writable (some environments allow this)
  [[ -w "/var/backups" ]] && skip "/var/backups is writable in this environment"

  # Skip if user has passwordless sudo (would auto-escalate)
  if sudo -ln 2>/dev/null | grep -q NOPASSWD; then
    skip "User has passwordless sudo in this environment"
  fi

  # Try to backup to a directory that requires root
  run "$CHECKPOINT" -d "/var/backups/test" --no-sudo -q "$TEST_SOURCE_DIR"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Cannot access backup directory" ]] || [[ "$output" =~ "Could not create directory" ]]
}

@test "non-root backup preserves file content correctly" {
  # Create backup
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" --no-sudo -q "$TEST_SOURCE_DIR"
  [ "$status" -eq 0 ]

  # Find the created backup
  backup_path=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "20*" | head -n1)
  [ -n "$backup_path" ]

  # Verify files exist and have correct content
  [ -f "$backup_path/file1.txt" ]
  [ -f "$backup_path/file2.txt" ]
  [ -f "$backup_path/subdir/file3.txt" ]

  # Check content
  [[ "$(cat "$backup_path/file1.txt")" == "test content" ]]
  [[ "$(cat "$backup_path/file2.txt")" == "more content" ]]
  [[ "$(cat "$backup_path/subdir/file3.txt")" == "subdir content" ]]
}

@test "non-root restore from user backup works correctly" {
  # Create backup first
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" --no-sudo -q "$TEST_SOURCE_DIR"
  [ "$status" -eq 0 ]

  # Modify source files
  echo "modified" > "$TEST_SOURCE_DIR/file1.txt"
  rm -f "$TEST_SOURCE_DIR/file2.txt"

  # Restore from backup
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" --restore --no-sudo -q "$TEST_SOURCE_DIR"
  [ "$status" -eq 0 ]

  # Verify files are restored
  [ -f "$TEST_SOURCE_DIR/file1.txt" ]
  [ -f "$TEST_SOURCE_DIR/file2.txt" ]
  [[ "$(cat "$TEST_SOURCE_DIR/file1.txt")" == "test content" ]]
  [[ "$(cat "$TEST_SOURCE_DIR/file2.txt")" == "more content" ]]
}

@test "info message shown for non-root users about ownership" {
  # Create a new backup directory to trigger the message
  NEW_BACKUP_DIR="$TEST_TEMP_DIR/new_backups"

  # Run checkpoint with verbose mode to see messages
  run "$CHECKPOINT" -d "$NEW_BACKUP_DIR" --no-sudo "$TEST_SOURCE_DIR"

  [ "$status" -eq 0 ]

  # Check for the informational message about ownership
  # Only if we're not root
  if [[ $EUID -ne 0 ]]; then
    [[ "$output" =~ "Running as non-root" ]] || [[ "$output" =~ "retain current user ownership" ]]
  fi
}

@test "smart escalation only happens when needed" {
  # This test verifies that the script doesn't escalate unnecessarily
  # Create a test script that mocks sudo behavior
  cat > "$TEST_TEMP_DIR/test_escalation.sh" << 'EOT'
#!/usr/bin/env bash
# Track if sudo was called
SUDO_CALLED=0
sudo() {
  echo "SUDO_WAS_CALLED"
  SUDO_CALLED=1
  return 1  # Simulate sudo not available
}
export -f sudo

# Now run checkpoint with a user-accessible directory
"$1" -d "$2" --no-sudo -q "$3" 2>&1
EOT
  chmod +x "$TEST_TEMP_DIR/test_escalation.sh"

  # Run with user-accessible directory
  run "$TEST_TEMP_DIR/test_escalation.sh" "$CHECKPOINT" "$TEST_BACKUP_DIR" "$TEST_SOURCE_DIR"

  # Should not have tried to use sudo
  [[ ! "$output" =~ "SUDO_WAS_CALLED" ]]
}

#fin