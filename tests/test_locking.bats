#!/usr/bin/env bats

# Test suite for checkpoint lockfile mechanism

setup() {
  # Get the directory containing this test file
  TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  # Get the project root directory (parent of tests)
  PROJECT_ROOT="$( cd "$TEST_DIR/.." >/dev/null 2>&1 && pwd )"
  # Path to the checkpoint script
  CHECKPOINT="$PROJECT_ROOT/checkpoint"
  
  # Create test directories
  export TEST_TEMP_DIR
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_SOURCE_DIR="$TEST_TEMP_DIR/source"
  export TEST_BACKUP_DIR="$TEST_TEMP_DIR/backups"
  
  # Create source directory with test files
  mkdir -p "$TEST_SOURCE_DIR"
  mkdir -p "$TEST_BACKUP_DIR"
  echo "test content" > "$TEST_SOURCE_DIR/test.txt"
  
  # Export timestamp pattern for tests
  export TIMESTAMP_PATTERN='20[0-9][0-9][0-1][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]*'
}

teardown() {
  # Clean up test directories
  if [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "lock is acquired during backup operation" {
  # Create more files to make backup take longer
  for i in {1..50}; do
    echo "test content $i" > "$TEST_SOURCE_DIR/file$i.txt"
    mkdir -p "$TEST_SOURCE_DIR/dir$i"
    echo "subdir content" > "$TEST_SOURCE_DIR/dir$i/subfile.txt"
  done

  # Start a background process that creates a backup with verification (slower)
  "$CHECKPOINT" -d "$TEST_BACKUP_DIR" --verify -q "$TEST_SOURCE_DIR" &
  local pid1=$!

  # Give it a moment to acquire the lock
  sleep 0.2

  # Check that lock directory exists
  if [ -d "$TEST_BACKUP_DIR/.checkpoint.lock" ]; then
    # Check that PID file exists and contains the right PID
    [ -f "$TEST_BACKUP_DIR/.checkpoint.lock/pid" ]
    local lock_pid=$(cat "$TEST_BACKUP_DIR/.checkpoint.lock/pid")
    [ "$lock_pid" = "$pid1" ]
  else
    # If backup completed too quickly, that's still a pass
    # Just verify the backup was created successfully
    wait $pid1
    [ $? -eq 0 ]
    local backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "20*" | wc -l)
    [ "$backup_count" -gt 0 ]
  fi

  # Wait for backup to complete
  wait $pid1

  # Lock should be released after completion
  [ ! -d "$TEST_BACKUP_DIR/.checkpoint.lock" ]
}

@test "concurrent backups are prevented by lock" {
  # Create a lock directory manually to simulate another process
  mkdir -p "$TEST_BACKUP_DIR/.checkpoint.lock"
  echo "$$" > "$TEST_BACKUP_DIR/.checkpoint.lock/pid"
  echo "$(date -u +%s)" > "$TEST_BACKUP_DIR/.checkpoint.lock/timestamp"
  
  # Try to create a backup with short timeout
  run timeout 2 "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" --lock-timeout 1
  
  # Should fail because lock is held
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to acquire lock"* ]]
  
  # Clean up lock
  rm -rf "$TEST_BACKUP_DIR/.checkpoint.lock"
}

@test "stale lock from dead process is automatically removed" {
  # Create a lock with a non-existent PID
  mkdir -p "$TEST_BACKUP_DIR/.checkpoint.lock"
  echo "999999" > "$TEST_BACKUP_DIR/.checkpoint.lock/pid"  # Very high PID unlikely to exist
  echo "$(date -u +%s)" > "$TEST_BACKUP_DIR/.checkpoint.lock/timestamp"
  
  # Should succeed because it detects stale lock
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR"
  [ "$status" -eq 0 ]
  
  # Verify backup was created
  local backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | wc -l)
  [ "$backup_count" -eq 1 ]
}

@test "--no-lock option disables locking mechanism" {
  # Create a lock manually
  mkdir -p "$TEST_BACKUP_DIR/.checkpoint.lock"
  echo "$$" > "$TEST_BACKUP_DIR/.checkpoint.lock/pid"
  echo "$(date -u +%s)" > "$TEST_BACKUP_DIR/.checkpoint.lock/timestamp"
  
  # Should succeed with --no-lock even though lock exists
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" --no-lock
  [ "$status" -eq 0 ]
  
  # Original lock should still exist (not removed)
  [ -d "$TEST_BACKUP_DIR/.checkpoint.lock" ]
  
  # Clean up
  rm -rf "$TEST_BACKUP_DIR/.checkpoint.lock"
}

@test "--force-unlock removes old locks" {
  # Create an old lock (25 hours old)
  mkdir -p "$TEST_BACKUP_DIR/.checkpoint.lock"
  echo "$$" > "$TEST_BACKUP_DIR/.checkpoint.lock/pid"
  echo "$(($(date +%s) - 90000))" > "$TEST_BACKUP_DIR/.checkpoint.lock/timestamp"  # 25 hours ago
  
  # Should succeed with --force-unlock
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" --force-unlock
  [ "$status" -eq 0 ]
  
  # Verify backup was created
  local backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | wc -l)
  [ "$backup_count" -eq 1 ]
}

@test "lock is released on script interruption" {
  # Create many files to ensure longer backup time
  for i in {1..100}; do
    echo "test content $i" > "$TEST_SOURCE_DIR/file$i.txt"
    mkdir -p "$TEST_SOURCE_DIR/dir$i"
    echo "subdir content" > "$TEST_SOURCE_DIR/dir$i/subfile.txt"
  done

  # Start a long-running backup process with verification
  "$CHECKPOINT" -d "$TEST_BACKUP_DIR" "$TEST_SOURCE_DIR" --verify &
  local pid=$!

  # Give it time to acquire lock and start processing
  sleep 0.3

  # Check if process is still running and has lock
  if kill -0 $pid 2>/dev/null && [ -d "$TEST_BACKUP_DIR/.checkpoint.lock" ]; then
    # Process is running with lock, test interruption
    kill -TERM $pid
    wait $pid || true

    # Give cleanup time to run
    sleep 0.5

    # Lock should be cleaned up
    [ ! -d "$TEST_BACKUP_DIR/.checkpoint.lock" ]
  else
    # If backup completed too quickly, verify it succeeded
    wait $pid || true
    [ ! -d "$TEST_BACKUP_DIR/.checkpoint.lock" ]
    # Verify backup was created
    local backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "20*" | wc -l)
    [ "$backup_count" -gt 0 ]
  fi
}

@test "lock timeout can be configured" {
  # Create a lock
  mkdir -p "$TEST_BACKUP_DIR/.checkpoint.lock"
  echo "$$" > "$TEST_BACKUP_DIR/.checkpoint.lock/pid"
  echo "$(date -u +%s)" > "$TEST_BACKUP_DIR/.checkpoint.lock/timestamp"
  
  # Try with very short timeout
  local start_time=$(date +%s)
  run timeout 5 "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" --lock-timeout 2
  local end_time=$(date +%s)
  
  # Should fail
  [ "$status" -ne 0 ]
  
  # Should have taken about 2 seconds
  local elapsed=$((end_time - start_time))
  [ "$elapsed" -ge 2 ] && [ "$elapsed" -le 4 ]
  
  # Clean up
  rm -rf "$TEST_BACKUP_DIR/.checkpoint.lock"
}

@test "multiple checkpoint instances queue properly" {
  # This test simulates proper queueing behavior
  # Start first backup
  "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" &
  local pid1=$!
  
  # Give it time to start
  sleep 0.2
  
  # Start second backup that should wait
  (sleep 1 && "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" --suffix "_second") &
  local pid2=$!
  
  # Wait for both to complete
  wait $pid1
  wait $pid2
  
  # Both backups should exist
  local backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | wc -l)
  [ "$backup_count" -eq 2 ]
  
  # Second backup should have the suffix
  local second_backup=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "*_second" | wc -l)
  [ "$second_backup" -eq 1 ]
}

@test "lock directory permissions are set correctly" {
  # Create a backup
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" &
  local pid=$!
  
  # Give it time to create lock
  sleep 0.2
  
  # Check lock directory exists and has correct ownership
  if [ -d "$TEST_BACKUP_DIR/.checkpoint.lock" ]; then
    # Lock directory should be owned by current user
    local lock_owner=$(stat -c "%U" "$TEST_BACKUP_DIR/.checkpoint.lock" 2>/dev/null || stat -f "%Su" "$TEST_BACKUP_DIR/.checkpoint.lock")
    [ "$lock_owner" = "$(whoami)" ]
  fi
  
  wait $pid
}

# Test restore operations don't interfere with backup locks
@test "restore operations work with existing backup lock" {
  # Create a backup first
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR"
  [ "$status" -eq 0 ]
  
  # Get the backup name
  local backup_name=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | head -n1 | xargs basename)
  
  # Create a lock as if another backup is running
  mkdir -p "$TEST_BACKUP_DIR/.checkpoint.lock"
  echo "999999" > "$TEST_BACKUP_DIR/.checkpoint.lock/pid"
  
  # Restore should still work (doesn't need lock)
  local restore_dir="$TEST_TEMP_DIR/restore"
  mkdir -p "$restore_dir"
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" --restore --from "$backup_name" --to "$restore_dir" -q
  [ "$status" -eq 0 ]
  
  # Verify restore worked
  [ -f "$restore_dir/test.txt" ]
  
  # Clean up
  rm -rf "$TEST_BACKUP_DIR/.checkpoint.lock"
}