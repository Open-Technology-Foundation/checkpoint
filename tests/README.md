# Checkpoint Test Suite

This directory contains the test suite for the `checkpoint` script using BATS (Bash Automated Testing System).

## Overview

The test suite validates the functionality of the checkpoint script, including:

- Basic backup creation and verification
- Handling of different command-line options
- Error handling and edge cases
- Path canonicalization
- Disk space checking
- Multiple backup creation
- Filesystem operations

## Running Tests

### Prerequisites

- BATS installed on your system (https://github.com/bats-core/bats-core)
- Standard Linux/Unix utilities: bash, find, rsync, stat

### Running All Tests

```bash
./run_tests.sh
```

### Running a Single Test

```bash
./run_single_test.sh "test name"
```

Example:
```bash
./run_single_test.sh "basic backup creation"
```

## Test Structure

The tests are organized in the following way:

1. **Setup Phase**: Each test creates a temporary directory structure with source files and directories.

2. **Test Execution**: Tests run the checkpoint script with various parameters.

3. **Validation**: Tests verify the results (exit codes, output messages, and created files).

4. **Teardown Phase**: Temporary directories are removed after each test.

## Test File Organization

- `test_checkpoint.bats` - Main test file containing all test cases
- `run_tests.sh` - Helper script to run all tests
- `run_single_test.sh` - Helper script to run a specific test by name
- `README.md` - This documentation file

## Adding New Tests

To add a new test:

1. Open `test_checkpoint.bats`
2. Add a new test function using the BATS `@test` notation:

```bash
@test "description of your test" {
  # Setup specific to this test (if needed)
  
  # Run the command
  run "$CHECKPOINT" [options]
  
  # Assertions
  [ "$status" -eq 0 ]  # Check exit status
  [[ "$output" =~ expected_pattern ]]  # Check output
  [ -f "expected_file" ]  # Check file existence
  
  # Additional verifications as needed
}
```

## Test Helper Functions

The test suite includes several helper functions:

- `setup()` - Creates the test environment before each test
- `teardown()` - Cleans up after each test
- `count_backups()` - Utility to count the number of backups in the test directory

## Best Practices

When writing new tests:

1. Each test should be independent and not rely on state from other tests
2. Clean up all temporary files and directories
3. Test both success and error cases
4. Verify actual behaviors, not just exit codes
5. Use descriptive test names that clearly indicate what's being tested