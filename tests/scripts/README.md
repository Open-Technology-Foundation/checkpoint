# Checkpoint Test Scripts

This directory contains standalone test scripts for testing specific features of the checkpoint utility.

## Available Scripts

- **test_metadata.sh**: Tests and demonstrates metadata display functionality
  - Usage: `./test_metadata.sh <checkpoint_dir>`

- **test_remote.sh**: Sets up a test environment for remote backup functionality
  - Usage: `./test_remote.sh`

- **search_metadata.sh**: Searches for backups matching specific metadata criteria
  - Usage: `./search_metadata.sh <backup_dir> <key> <value>`

- **update_metadata.sh**: Updates metadata for an existing checkpoint
  - Usage: `./update_metadata.sh <checkpoint_dir> <key> <value>`

- **ssh_test.sh**: Tests SSH connectivity for remote backup functionality
  - Usage: `./ssh_test.sh [host] [user]`

## Running the Scripts

These scripts should be run from the project root directory:

```bash
./tests/scripts/test_metadata.sh <checkpoint_dir>
./tests/scripts/search_metadata.sh <backup_dir> <key> <value>
# etc.
```

## Integration with Main Tests

These scripts are complementary to the main BATS test suite (`test_checkpoint.bats`).
While the BATS tests focus on functional validation, these scripts provide:

1. Isolated testing of specific features
2. Demonstration of functionality
3. Debugging tools for troubleshooting
4. Test environment setup for manual testing