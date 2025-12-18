# Checkpoint

A powerful cross-platform utility for creating, managing, and restoring timestamped snapshots of directories. Designed specifically for developers, system administrators, and DevOps engineers who need reliable recovery points during iterative development and system configuration changes.

## Overview

Checkpoint bridges the gap between informal backup practices and enterprise-grade snapshot management by providing simple commands for complex operations. Create recovery points before risky changes, track development progress through organized snapshots, and quickly restore when needed—all while maintaining security and automation compatibility.

### Key Benefits

- **Development Safety**: Create quick recovery points before risky code changes
- **Visual Change Tracking**: Compare differences between snapshots to understand evolution
- **Flexible Recovery**: Restore entire directories or specific file patterns
- **Cross-Platform**: Consistent behavior on Linux and macOS systems
- **Automation Ready**: Works reliably in CI/CD pipelines and scripts
- **Non-Root Friendly**: Works seamlessly for regular users with smart directory defaults

## Core Features

- **Smart Snapshots**: Creates timestamped backups with automatic exclusions and metadata
- **Intelligent Defaults**: Automatically selects appropriate backup directories based on user privileges
- **Atomic Operations**: Ensures backup integrity with temporary directories and atomic rename
- **Concurrency Protection**: Lockfile mechanism prevents data corruption from parallel operations
- **Powerful Comparison**: Visualizes differences between snapshots with color-coded output
- **Flexible Restoration**: Supports complete or selective file recovery with preview mode
- **Metadata Management**: Attaches searchable descriptions and tags to checkpoints
- **Remote Operations**: Creates and restores backups on remote hosts via secure SSH
- **Space Optimization**: Uses hardlinking between versions to minimize disk usage
- **Backup Rotation**: Manages history by count or age for automatic cleanup
- **Automation Support**: Non-interactive operation with timeout safeguards
- **Smart Privilege Handling**: Only escalates privileges when necessary, works without sudo

## Installation

### One-Line Install

```bash
# Install with automatic dependency installation
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/install.sh | bash

# Or with wget
wget -qO- https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/install.sh | bash

# Install to custom location (no sudo required)
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/install.sh | INSTALL_DIR=~/.local/bin bash
```

The installer also:
- Creates a `chkpoint` symlink for convenience
- Installs the man page (`man checkpoint`)
- Installs bash completion for tab completion

### Manual Install

```bash
# Download script and make executable
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/checkpoint -o checkpoint
chmod +x checkpoint
sudo cp checkpoint /usr/local/bin/

# Install man page
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/checkpoint.1 -o checkpoint.1
sudo cp checkpoint.1 /usr/local/share/man/man1/
sudo mandb

# Install bash completion
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/checkpoint.bash_completion -o checkpoint.bash_completion
sudo cp checkpoint.bash_completion /usr/share/bash-completion/completions/checkpoint

# Optional: Install hardlink for space efficiency
sudo apt install hardlink  # Ubuntu/Debian
# or
brew install hardlink       # macOS
```

### Requirements

**Core Dependencies** (required):
- `rsync` - File synchronization
- `find` - File discovery
- `stat` - File metadata

**Optional Dependencies**:
- `hardlink` - Space-efficient backup storage
- `delta` or `colordiff` - Enhanced diff visualization
- SSH client - For remote operations only

## Quick Start

### For Non-Root Users

```bash
# Create checkpoint of current directory (backs up to ~/.checkpoint/)
checkpoint

# Backup a specific directory
checkpoint ~/my-project

# Use custom backup location
checkpoint -d ~/backups/project ~/my-project

# Set default backup directory for all operations
export CHECKPOINT_BACKUP_DIR=~/my-backups
checkpoint ~/my-project
```

### Basic Operations

```bash
# Create checkpoint of current directory
checkpoint

# Create checkpoint with descriptive name
checkpoint -s "before-refactor"

# List all checkpoints
checkpoint --list

# Restore latest checkpoint
checkpoint --restore

# Compare current files with checkpoint
checkpoint --restore --diff
```

## Usage Examples

### Development Workflow

```bash
# Before major changes
checkpoint -s "pre-api-refactor" --desc "Stable baseline before API changes"

# Create checkpoint with metadata
checkpoint --desc "Release candidate v2.1.0" --tag "version=2.1.0" --tag "status=testing"

# Compare with previous state
checkpoint --restore --diff

# Restore if needed
checkpoint --restore --from 20250430_091429
```

### System Administration

```bash
# Backup configuration before updates
sudo checkpoint -d /var/backups/system /etc

# Web server configuration checkpoint
checkpoint -s "ssl-optimization" /etc/nginx

# Compare configuration changes
checkpoint --from 20250430_091429 --compare-with 20250430_101530 --detailed
```

### Selective Operations

```bash
# Restore only specific files
checkpoint --restore --files "*.js" --files "docs/*.md"

# Dry run to preview changes
checkpoint --restore --dry-run

# Custom backup location
checkpoint -d ~/backups/myproject

# Exclude specific patterns
checkpoint --exclude "node_modules/" --exclude "*.log"
```

### Remote Operations

```bash
# Create backup on remote server
checkpoint --remote user@host:/path/to/backups

# List remote checkpoints
checkpoint --remote user@host:/path/to/backups --list

# Restore from remote checkpoint
checkpoint --remote user@host:/path/to/backups --restore --from 20250430_091429
```

### Backup Management

```bash
# Automatic rotation: keep only 5 most recent
checkpoint --keep 5

# Age-based rotation: remove backups older than 30 days
checkpoint --age 30

# Prune without creating new backup
checkpoint --prune-only --keep 3

# Verify backup integrity
checkpoint --verify
```

### Concurrency Protection

Checkpoint includes a lockfile mechanism to prevent data corruption from concurrent operations:

```bash
# Normal operation (locking enabled by default)
checkpoint

# Disable locking (DANGEROUS - allows concurrent operations)
checkpoint --no-lock

# Set custom lock timeout (default: 300 seconds)
checkpoint --lock-timeout 60

# Force removal of stale locks
checkpoint --force-unlock
```

The locking mechanism:
- Prevents multiple checkpoint instances from operating on the same backup directory
- Automatically detects and removes stale locks from crashed processes
- Works with both local and remote operations
- Can be disabled for special use cases (use with caution)

### Metadata Operations

```bash
# Search for checkpoints
checkpoint --metadata --find "version=2.1.0"

# Show checkpoint details
checkpoint --metadata --show 20250430_091429

# Update existing checkpoint metadata
checkpoint --metadata --update 20250430_091429 --set "status=approved"
```

## Command Reference

### Core Options

| Option | Description |
|--------|-------------|
| `-d, --backup-dir DIR` | Custom backup location (default: context-dependent) |
| `-s, --suffix SUF` | Add descriptive suffix to checkpoint name |
| `-n, --no-hardlink` | Do not hardlink to previous backup |
| `--hardlink` | Hardlink to previous backup (default if available) |
| `-q, --quiet` | Minimal output (just backup path) |
| `-v, --verbose` | Detailed output with progress (default) |
| `-l, --list` | List existing checkpoints with sizes |
| `-x, --exclude PATTERN` | Additional exclusion pattern (repeatable) |
| `--debug` | Show debug information during operation |
| `-V, --version` | Print version and exit |
| `-h, --help` | Display help |

### Backup Management

| Option | Description |
|--------|-------------|
| `--keep N` | Keep only N most recent backups |
| `--age DAYS` | Remove backups older than DAYS days |
| `-p, --prune-only` | Only prune backups without creating new one |
| `--verify` | Verify backup integrity after creation |
| `--no-sudo` | Never attempt privilege escalation |
| `--no-lock` | Disable lockfile mechanism (DANGEROUS) |
| `--lock-timeout N` | Lock acquisition timeout in seconds (default: 300) |
| `--force-unlock` | Force removal of stale locks |

### Restore and Compare

| Option | Description |
|--------|-------------|
| `-r, --restore` | Restore from checkpoint |
| `-f, --from ID` | Source checkpoint (defaults to most recent) |
| `-t, --to DIR` | Target restore directory (defaults to original) |
| `--dry-run` | Preview changes without making them |
| `--diff` | Show differences between current files and checkpoint |
| `--compare-with ID` | Compare two checkpoints |
| `--detailed` | Show file content differences in comparison |
| `--files PATTERN` | Select specific files/patterns (repeatable) |

### Metadata

| Option | Description |
|--------|-------------|
| `--desc TEXT` | Add description to checkpoint |
| `--system NAME` | Set source system name in metadata |
| `--tag KEY=VALUE` | Add searchable metadata tag (repeatable) |
| `--metadata` | Access checkpoint metadata |
| `--show ID` | Show metadata for checkpoint ID |
| `--update ID` | Update metadata for checkpoint ID |
| `--find PATTERN` | Find checkpoints matching metadata pattern |
| `--set KEY=VALUE` | Set/update metadata key-value pair |

### Remote Operations

| Option | Description |
|--------|-------------|
| `--remote SPEC` | Remote location (`user@host:/path`) |
| `--timeout SECONDS` | SSH connection timeout (default: 30s) |

## Automation Integration

### Environment Variables

```bash
# Set default backup directory for all operations
export CHECKPOINT_BACKUP_DIR=~/my-backups

# Skip interactive prompts
export CHECKPOINT_AUTO_CONFIRM=1
```

### CI/CD Examples

```bash
# GitHub Actions / GitLab CI
- name: Create Checkpoint
  run: CHECKPOINT_AUTO_CONFIRM=1 checkpoint -s "build-${GITHUB_RUN_NUMBER}"

# Jenkins Pipeline
stage('Backup') {
    steps {
        sh 'CHECKPOINT_AUTO_CONFIRM=1 checkpoint -s "build-${BUILD_NUMBER}"'
    }
}

# Cron job for regular backups
0 2 * * * CHECKPOINT_AUTO_CONFIRM=1 /usr/local/bin/checkpoint -d /var/backups/nightly /home/user/project
```

### Timeout Protection

All interactive prompts have built-in timeouts:
- Directory creation: 30 seconds
- Restore confirmation: 30 seconds  
- Checkpoint selection: 60 seconds

## Backup Directory Locations

### Smart Directory Selection

Checkpoint intelligently selects backup directories based on your user context:

| User Type | Default Location | Example |
|-----------|------------------|---------|
| Root/sudo | `/var/backups/DIR_NAME/` | `/var/backups/myproject/` |
| Regular user | `~/.checkpoint/DIR_NAME/` | `~/.checkpoint/myproject/` |
| Custom | `$CHECKPOINT_BACKUP_DIR/DIR_NAME/` | `~/backups/myproject/` |

### Privilege Management

- **Automatic Detection**: Checkpoint only requests sudo when the backup directory requires it
- **Non-Root Friendly**: Regular users can backup to any writable directory without sudo
- **Explicit Control**: Use `--no-sudo` to prevent any privilege escalation
- **Smart Escalation**: If a directory needs privileges and sudo is available, checkpoint will automatically escalate

```bash
# Force non-root operation
checkpoint --no-sudo ~/myproject

# Let checkpoint decide (recommended)
checkpoint ~/myproject
```

## Default Exclusions

These patterns are automatically excluded from all backups:
- Backup directory itself (prevents recursion)
- `.gudang/`, `temp/`, `.temp/`, `tmp/` directories
- Temporary files: `*~` and `~*`
- `.tmp.*` directories (atomic operation temporaries)
- `.checkpoint.lock/` directories (concurrency locks)

## Storage and Performance

### Space Efficiency

With hardlinking enabled, checkpoint can achieve 90%+ space savings between similar versions by sharing identical files. Example:

```bash
# First backup: 100MB
checkpoint -s "v1.0"

# Second backup: Only changed files use additional space
checkpoint -s "v1.1"  # Might only use 5MB additional space
```

### Atomic Operations

Checkpoint uses atomic operations to ensure backup integrity:

- **Temporary Directory**: Backups are created in a `.tmp.*` directory first
- **Atomic Rename**: Only after all operations succeed is the backup renamed to its final name
- **Automatic Cleanup**: Temporary directories are removed on interruption or failure
- **No Partial States**: You'll never see incomplete or corrupted backups

This means:
- Interrupted backups leave no trace
- Concurrent operations are safe (with locking enabled)
- Backup directories appear instantaneously when complete
- Failed operations are automatically cleaned up

### Performance Characteristics

- **Backup Speed**: Limited by rsync performance and storage I/O
- **Comparison Speed**: Optimized with size-based verification for large datasets
- **Scalability**: Handles projects from small configs to large codebases
- **Memory Usage**: Minimal footprint, primarily shell variables

## Development

### Testing

```bash
# Lint code (must pass without errors)
shellcheck checkpoint

# Run all test suites with summary
./run_all_tests.sh

# Run all test suites
bats tests/*.bats

# Run individual test suites
bats tests/test_checkpoint.bats    # Core functionality (33 tests)
bats tests/test_locking.bats       # Concurrency protection (10 tests)
bats tests/test_atomic.bats        # Atomic operations (9 tests)
bats tests/test_remote.bats        # Remote operations (17 tests)
bats tests/test_nonroot.bats       # Non-root user operations (9 tests)

# Run specific test by name
bats tests/test_checkpoint.bats -f "backup creation"

# Verbose testing
bats -v tests/test_checkpoint.bats

# Enable real SSH integration tests (skipped by default)
CHECKPOINT_TEST_SSH=1 CHECKPOINT_TEST_HOST=user@host:/path bats tests/test_remote.bats
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following existing code style:
   - 2-space indentation (never tabs)
   - `set -euo pipefail` error handling
   - Use `[[` for conditionals, `(( ))` for arithmetic
   - Comprehensive function documentation headers
   - BATS tests for new functionality
   - End all scripts with `#fin` marker
4. Run `shellcheck checkpoint` (must pass without errors)
5. Run `bats tests/*.bats` (all tests must pass)
6. Submit pull request

## Troubleshooting

### Common Issues

**Permission Denied**: Use `--no-sudo` for user-accessible directories or ensure sudo access.

**SSH Connection Failed**: Verify SSH key setup and network connectivity for remote operations.

**Insufficient Disk Space**: Check available space in backup directory before large operations.

**Command Not Found**: Ensure all required dependencies (`rsync`, `find`, `stat`) are installed.

**Failed to Acquire Lock**: Another checkpoint process may be running. Use `--force-unlock` to remove stale locks from crashed processes, or wait for the other operation to complete.

### Debug Mode

```bash
# Enable debug output
checkpoint --debug

# Verify backup integrity
checkpoint --verify

# Compare with source to check differences
checkpoint --restore --diff
```

## Security

- **Input Validation**: Strict pattern matching prevents injection attacks
- **SSH Hardening**: Secure default options for remote operations
- **Path Protection**: Prevents directory traversal attacks
- **Privilege Management**: Optional sudo with explicit bypass option

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Version

Current version: **1.6.1**

### Recent Features

#### v1.6.1 - Documentation and Tooling
- **Comprehensive manpage**: Full Unix manpage with all 35+ options documented
- **Enhanced bash completion**: Dynamic checkpoint ID completion for restore/compare operations
- **Script documentation**: All scripts updated with headers, usage docs, and #fin markers
- **Installer improvements**: Now installs manpage and bash completion automatically
- **Fixed test scripts**: Corrected corrupted shebangs and BCS compliance issues

#### v1.6.0 - Code Quality and Standards Compliance
- **Full BASH-CODING-STANDARD.md compliance**: Refactored entire codebase to meet strict coding standards
- **Enhanced messaging system**: New standardized output functions with visual indicators (✓ for success, ✗ for errors)
- **Improved variable handling**: Proper type declarations for all variables (integers, arrays, strings)
- **Better error handling**: Consistent error codes and messaging throughout
- **Verification improvements**: Fixed file exclusion handling during backup verification
- **Code modernization**: Updated arithmetic operations, fixed shellcheck warnings, improved quoting

#### v1.5.0 - Atomic Operations
- Implemented atomic backup operations using temporary directories
- Added automatic cleanup of interrupted operations
- Ensured backup integrity with atomic rename after completion
- Applied atomic pattern to both local and remote operations

#### v1.4.0 - Concurrency Protection
- Added lockfile mechanism to prevent concurrent operations
- Implemented PID-based lock ownership verification
- Added stale lock detection and automatic cleanup
- Introduced --no-lock, --lock-timeout, and --force-unlock options
- Extended locking to remote operations via SSH

#### v1.3.0 - Enhanced Metadata and Remote Operations
- Improved metadata management system
- Enhanced remote operation capabilities
- Added comprehensive remote testing framework

For detailed version history, see the commit log or check `checkpoint --version`.