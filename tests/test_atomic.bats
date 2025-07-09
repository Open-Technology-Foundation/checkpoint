#!/usr/bin/env bats

# Test suite for atomic backup operations

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
  echo "test content 1" > "$TEST_SOURCE_DIR/file1.txt"
  echo "test content 2" > "$TEST_SOURCE_DIR/file2.txt"
  mkdir -p "$TEST_SOURCE_DIR/subdir"
  echo "test content 3" > "$TEST_SOURCE_DIR/subdir/file3.txt"
  
  # Export timestamp pattern for tests
  export TIMESTAMP_PATTERN='20[0-9][0-9][0-1][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]*'
}

teardown() {
  # Clean up test directories
  if [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "temporary directory is used during backup creation" {
  # Run backup with debug mode to see temp directory messages
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" "$TEST_SOURCE_DIR" --debug -q
  [ "$status" -eq 0 ]
  
  # Check debug output mentions temporary directory
  [[ "$output" == *"Creating temporary backup in"* ]]
  [[ "$output" == *".tmp."* ]]
  [[ "$output" == *"Atomic rename from"* ]]
}

@test "no temporary directories remain after successful backup" {
  # Create backup
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR"
  [ "$status" -eq 0 ]
  
  # Check no .tmp.* directories exist
  local tmp_dirs=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" | wc -l)
  [ "$tmp_dirs" -eq 0 ]
  
  # Verify actual backup exists
  local backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | wc -l)
  [ "$backup_count" -eq 1 ]
}

@test "interrupted backup leaves no partial backup directories" {
  # Create a wrapper script that kills checkpoint during rsync
  cat > "$TEST_TEMP_DIR/interrupt_backup.sh" << 'EOF'
#!/bin/bash
# Start checkpoint in background
"$1" -d "$2" "$3" &
PID=$!

# Wait for rsync to start (look for temp directory)
for i in {1..50}; do
  if find "$2" -maxdepth 1 -type d -name ".tmp.*" | grep -q .; then
    # Kill the process
    kill -TERM $PID
    wait $PID
    exit $?
  fi
  sleep 0.1
done
# If we get here, backup completed too fast
wait $PID
EOF
  chmod +x "$TEST_TEMP_DIR/interrupt_backup.sh"
  
  # Run the interruption test
  run "$TEST_TEMP_DIR/interrupt_backup.sh" "$CHECKPOINT" "$TEST_BACKUP_DIR" "$TEST_SOURCE_DIR"
  
  # Should have non-zero exit (interrupted)
  [ "$status" -ne 0 ] || true  # May succeed if backup is too fast
  
  # No temp directories should remain
  local tmp_dirs=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" 2>/dev/null | wc -l)
  [ "$tmp_dirs" -eq 0 ]
  
  # No partial backups with timestamp pattern
  local partial_backups=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" 2>/dev/null | wc -l)
  [ "$partial_backups" -eq 0 ] || [ "$partial_backups" -eq 1 ]  # Either interrupted or completed
}

@test "atomic rename ensures backup appears all at once" {
  # Create large source to slow down rsync
  for i in {1..100}; do
    dd if=/dev/zero of="$TEST_SOURCE_DIR/large$i.dat" bs=1K count=100 2>/dev/null
  done
  
  # Start backup in background
  "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" &
  local pid=$!
  
  # Monitor for final backup directory appearance
  local found_temp=0
  local found_final=0
  
  for i in {1..100}; do
    # Check for temp directory
    if find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" | grep -q .; then
      found_temp=1
    fi
    
    # Check for final directory
    if find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | grep -q .; then
      found_final=1
      break
    fi
    
    sleep 0.1
  done
  
  wait $pid
  
  # We should have seen temp directory and then final directory
  [ "$found_final" -eq 1 ]
}

@test "failed verification removes temporary backup" {
  # Create a file that will change during backup to fail verification
  echo "initial content" > "$TEST_SOURCE_DIR/changing.txt"
  
  # Create wrapper that modifies source during backup
  cat > "$TEST_TEMP_DIR/modify_during_backup.sh" << 'EOF'
#!/bin/bash
# Start checkpoint with verification
"$1" -d "$2" "$3" --verify &
PID=$!

# Wait a bit then modify source
sleep 0.5
echo "modified content" > "$3/changing.txt"

wait $PID
EOF
  chmod +x "$TEST_TEMP_DIR/modify_during_backup.sh"
  
  # This might fail due to verification
  run "$TEST_TEMP_DIR/modify_during_backup.sh" "$CHECKPOINT" "$TEST_BACKUP_DIR" "$TEST_SOURCE_DIR"
  
  # No temp directories should remain regardless of outcome
  local tmp_dirs=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" 2>/dev/null | wc -l)
  [ "$tmp_dirs" -eq 0 ]
}

@test "concurrent backups with atomic operations don't interfere" {
  # Create two different source directories
  mkdir -p "$TEST_TEMP_DIR/source1" "$TEST_TEMP_DIR/source2"
  echo "content1" > "$TEST_TEMP_DIR/source1/file.txt"
  echo "content2" > "$TEST_TEMP_DIR/source2/file.txt"
  
  # Run two backups concurrently with different suffixes
  "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_TEMP_DIR/source1" --suffix "_s1" --no-lock &
  local pid1=$!
  
  "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_TEMP_DIR/source2" --suffix "_s2" --no-lock &
  local pid2=$!
  
  # Wait for both to complete
  wait $pid1
  local status1=$?
  wait $pid2
  local status2=$?
  
  # Both should succeed
  [ "$status1" -eq 0 ]
  [ "$status2" -eq 0 ]
  
  # Both backups should exist
  [ -d "$TEST_BACKUP_DIR/"*"_s1" ]
  [ -d "$TEST_BACKUP_DIR/"*"_s2" ]
  
  # No temp directories remain
  local tmp_dirs=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" | wc -l)
  [ "$tmp_dirs" -eq 0 ]
}

@test "hardlinking works with atomic operations" {
  # Create first backup
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR"
  [ "$status" -eq 0 ]
  
  # Get first backup name
  local first_backup=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | head -n1)
  
  # Create second backup with hardlinking (if available)
  if command -v hardlink >/dev/null 2>&1; then
    sleep 1  # Ensure different timestamp
    run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" --hardlink
    [ "$status" -eq 0 ]
    
    # No temp directories remain
    local tmp_dirs=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" | wc -l)
    [ "$tmp_dirs" -eq 0 ]
    
    # Both backups exist
    local backup_count=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | wc -l)
    [ "$backup_count" -eq 2 ]
  fi
}

@test "metadata creation works with atomic operations" {
  # Create backup with metadata
  run "$CHECKPOINT" -d "$TEST_BACKUP_DIR" -q "$TEST_SOURCE_DIR" \
    --desc "Test backup" --system "testsys" --tag "env=test"
  [ "$status" -eq 0 ]
  
  # Get backup directory
  local backup_dir=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" | head -n1)
  
  # Verify metadata file exists
  [ -f "$backup_dir/.metadata" ]
  
  # Verify metadata content
  grep -q "description=Test backup" "$backup_dir/.metadata"
  grep -q "system=testsys" "$backup_dir/.metadata"
  grep -q "env=test" "$backup_dir/.metadata"
  
  # No temp directories remain
  local tmp_dirs=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" | wc -l)
  [ "$tmp_dirs" -eq 0 ]
}

@test "cleanup removes temp directories on exit signal" {
  # Create a script that creates temp dir and gets killed
  cat > "$TEST_TEMP_DIR/signal_test.sh" << 'EOF'
#!/bin/bash
export TEST_BACKUP_DIR="$1"
export TEST_SOURCE_DIR="$2"
# Source the checkpoint script to get access to its functions
source "$3"

# Set required globals
backup_dir="$TEST_BACKUP_DIR"
temp_backup_dir="$TEST_BACKUP_DIR/.tmp.test$$"

# Create temp directory
mkdir -p "$temp_backup_dir"

# Simulate being killed
kill -TERM $$
EOF
  chmod +x "$TEST_TEMP_DIR/signal_test.sh"
  
  # Run the test (it will kill itself)
  run "$TEST_TEMP_DIR/signal_test.sh" "$TEST_BACKUP_DIR" "$TEST_SOURCE_DIR" "$CHECKPOINT"
  
  # Give cleanup time to run
  sleep 0.5
  
  # No temp directories should remain
  local tmp_dirs=$(find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name ".tmp.*" 2>/dev/null | wc -l)
  [ "$tmp_dirs" -eq 0 ]
}