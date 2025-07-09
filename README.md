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

## Core Features

- **Smart Snapshots**: Creates timestamped backups with automatic exclusions and metadata
- **Powerful Comparison**: Visualizes differences between snapshots with color-coded output
- **Flexible Restoration**: Supports complete or selective file recovery with preview mode
- **Metadata Management**: Attaches searchable descriptions and tags to checkpoints
- **Remote Operations**: Creates and restores backups on remote hosts via secure SSH
- **Space Optimization**: Uses hardlinking between versions to minimize disk usage
- **Backup Rotation**: Manages history by count or age for automatic cleanup
- **Automation Support**: Non-interactive operation with timeout safeguards

## Installation

### Quick Install

```bash
# Make executable and install to system PATH
chmod +x checkpoint
sudo cp checkpoint /usr/local/bin/

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
| `-d, --backup-dir DIR` | Custom backup location (default: `/var/backups/DIR_NAME`) |
| `-s, --suffix SUF` | Add descriptive suffix to checkpoint name |
| `-q, --quiet` | Minimal output (just backup path) |
| `-v, --verbose` | Detailed output with progress (default) |
| `-l, --list` | List existing checkpoints with sizes |

### Backup Management

| Option | Description |
|--------|-------------|
| `--keep N` | Keep only N most recent backups |
| `--age DAYS` | Remove backups older than DAYS days |
| `--exclude PATTERN` | Additional exclusion pattern (repeatable) |
| `--verify` | Verify backup integrity after creation |
| `--no-sudo` | Never attempt privilege escalation |
| `--hardlink` | Enable hardlinking for space efficiency |
| `--prune-only` | Remove old backups without creating new one |

### Restore and Compare

| Option | Description |
|--------|-------------|
| `--restore` | Restore from checkpoint |
| `--from ID` | Source checkpoint (defaults to most recent) |
| `--to DIR` | Target restore directory (defaults to original) |
| `--dry-run` | Preview changes without making them |
| `--diff` | Show differences before restoring |
| `--compare-with ID` | Compare two checkpoints |
| `--detailed` | Show file content differences in comparison |
| `--files PATTERN` | Select specific files/patterns (repeatable) |

### Metadata and Remote

| Option | Description |
|--------|-------------|
| `--desc TEXT` | Add description to checkpoint |
| `--tag KEY=VALUE` | Add searchable metadata tag (repeatable) |
| `--metadata` | Access checkpoint metadata |
| `--show ID`, `--update ID`, `--find PATTERN` | Metadata operations |
| `--remote SPEC` | Remote location (`user@host:/path`) |
| `--timeout SECONDS` | SSH connection timeout (default: 30s) |

## Automation Integration

### Environment Variables

```bash
export CHECKPOINT_AUTO_CONFIRM=1  # Skip interactive prompts
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

## Default Exclusions

These patterns are automatically excluded from all backups:
- Backup directory itself (prevents recursion)
- `.gudang/`, `temp/`, `.temp/`, `tmp/` directories
- Temporary files: `*~` and `~*`

## Storage and Performance

### Space Efficiency

With hardlinking enabled, checkpoint can achieve 90%+ space savings between similar versions by sharing identical files. Example:

```bash
# First backup: 100MB
checkpoint -s "v1.0"

# Second backup: Only changed files use additional space
checkpoint -s "v1.1"  # Might only use 5MB additional space
```

### Performance Characteristics

- **Backup Speed**: Limited by rsync performance and storage I/O
- **Comparison Speed**: Optimized with size-based verification for large datasets
- **Scalability**: Handles projects from small configs to large codebases
- **Memory Usage**: Minimal footprint, primarily shell variables

## Development

### Testing

```bash
# Lint code
shellcheck checkpoint

# Run all tests
bats tests/test_checkpoint.bats

# Run specific test
bats tests/test_checkpoint.bats -f "backup creation"

# Test remote functionality
bats tests/test_remote.bats

# Test locking mechanism
bats tests/test_locking.bats

# Verbose testing
bats -v tests/test_checkpoint.bats
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following existing code style:
   - 2-space indentation
   - `set -euo pipefail` error handling
   - Comprehensive function documentation
   - BATS tests for new functionality
4. Run tests and linting
5. Submit pull request

## Troubleshooting

### Common Issues

**Permission Denied**: Use `--no-sudo` for user-accessible directories or ensure sudo access.

**SSH Connection Failed**: Verify SSH key setup and network connectivity for remote operations.

**Insufficient Disk Space**: Check available space in backup directory before large operations.

**Command Not Found**: Ensure all required dependencies (`rsync`, `find`, `stat`) are installed.

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

Current version: **1.3.0**

For version history and changes, see the commit log or check `checkpoint --version`.