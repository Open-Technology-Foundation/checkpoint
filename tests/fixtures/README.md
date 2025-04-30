# Test Fixtures

This directory contains test data used by the checkpoint test suite.

## Directory Structure

- **test_dirs/**: Contains pre-configured directories for testing checkpoint functionality
  - **backups/**: Contains example backup snapshots
  - **metadata/**: Contains backups with metadata for testing metadata functions
  - **restore/**: Target directory for restore operations
  - **source/**: Example source directory with files to back up

## Using Fixtures

These fixtures are primarily used by the main BATS test suite, but can also be used
for manual testing or by the standalone test scripts.

Example:
```bash
# Use a specific backup for a restore test
./checkpoint --restore --from $(ls -1 tests/fixtures/test_dirs/backups/ | head -1) --to /tmp/restore_test
```