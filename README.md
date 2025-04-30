# Checkpoint

A cross-platform utility for creating, managing, and restoring timestamped snapshots of code and configuration directories.

## Overview

Checkpoint provides developers and system administrators with a reliable safety net for preserving directory states before making significant changes. It creates organized, timestamped snapshots with powerful comparison, metadata, and restoration capabilities.

Key features include selective restoration, detailed change visualization, remote operations via SSH, and flexible backup rotation - all designed to work consistently across Linux and macOS systems.

### Key Benefits

- **Development Safety**: Create quick recovery points before risky code changes
- **Timestamped History**: Track development progress with organized snapshots
- **Visualization**: Compare differences between snapshots to understand changes
- **Cross-Platform**: Consistent behavior on Linux and macOS/BSD systems
- **Flexible Recovery**: Restore entire directories or just specific files/patterns

## Core Features

- **Smart Snapshots**: Creates timestamped backups with descriptive labels
- **Powerful Comparison**: Visualizes differences between snapshots with colored output
- **Flexible Restoration**: Restores complete directories or specific file patterns
- **Metadata Management**: Attaches searchable descriptions and tags to checkpoints
- **Remote Operations**: Creates and restores backups on remote hosts via SSH
- **Space Optimization**: Uses hardlinking between versions to minimize disk usage
- **Backup Rotation**: Manages history by count or age for automatic cleanup
- **Automation Support**: Works in non-interactive environments with timeout handling

## Installation

```bash
chmod +x checkpoint
sudo cp checkpoint /usr/local/bin/
```

## Basic Usage

```bash
# Create checkpoint of current directory
checkpoint [OPTIONS] [directory]

# List available checkpoints
checkpoint --list [OPTIONS] [directory]

# Restore from checkpoint
checkpoint --restore [RESTORE_OPTIONS] [directory]
```

## Common Examples

### Creating Checkpoints

```bash
# Basic checkpoint of current directory
checkpoint

# Checkpoint with descriptive label
checkpoint -s "before-refactor"

# Checkpoint to custom location
checkpoint -d ~/backups/myproject

# Checkpoint with searchable metadata
checkpoint --desc "Pre-release version" --tag "version=1.0.0" --tag "status=testing"

# Checkpoint with backup rotation (keep only 5 most recent)
checkpoint --keep 5

# Remote checkpoint via SSH
checkpoint --remote user@host:/path/to/backups
```

### Comparing and Restoring

```bash
# List all available checkpoints
checkpoint --list

# Restore latest checkpoint
checkpoint --restore

# Restore specific checkpoint by ID
checkpoint --restore --from 20250430_091429

# Preview differences before restoring
checkpoint --restore --diff

# Restore to different directory
checkpoint --restore --from 20250430_091429 --to ~/restored-project

# Restore only specific files
checkpoint --restore --files "*.js" --files "docs/*.md"

# Compare two checkpoints with detailed diff
checkpoint --from 20250430_091429 --compare-with 20250430_101530 --detailed

# Restore from remote checkpoint
checkpoint --remote user@host:/path/to/backups --restore --from 20250430_091429
```

## Command Reference

### Core Options

- `-d, --backup-dir DIR` : Set custom backup location (default: /var/backups/DIR_NAME)
- `-s, --suffix SUF` : Add descriptive suffix to checkpoint name
- `-q, --quiet` : Minimal output (just backup path)
- `-v, --verbose` : Detailed output with progress (default)
- `-l, --list` : List existing checkpoints with sizes

### Backup Management

- `--keep N` : Keep only N most recent backups (rotation by count)
- `--age DAYS` : Remove backups older than DAYS days (rotation by age)
- `--exclude PATTERN` : Specify additional exclusion pattern (can use multiple times)
- `--verify` : Verify backup integrity after creation
- `--no-sudo` : Never attempt privilege escalation
- `--hardlink` : Enable hardlinking for space efficiency (default if available)
- `--prune-only` : Remove old backups without creating new one

### Metadata Options

- `--desc TEXT` : Add description to checkpoint
- `--tag KEY=VALUE` : Add searchable metadata tag (can use multiple times)
- `--metadata` : Access checkpoint metadata
- `--show ID` : Display metadata for specific checkpoint
- `--update ID` : Update metadata for existing checkpoint
- `--find PATTERN` : Search for checkpoints by metadata

### Remote Operations

- `--remote SPEC` : Remote location in format user@host:/path
- `--timeout SECONDS` : SSH connection timeout (default: 30s)

### Restore and Compare Options

- `--restore` : Restore from checkpoint
- `--from ID` : Specify source checkpoint (defaults to most recent)
- `--to DIR` : Set target restore directory (defaults to original location)
- `--dry-run` : Preview changes without making them
- `--diff` : Show differences before restoring
- `--compare-with ID` : Compare two checkpoints
- `--detailed` : Show file content differences in comparison
- `--files PATTERN` : Select specific files/patterns (can use multiple times)

## Automation Features

Checkpoint is designed to work reliably in automated environments with several safeguards:

### Environment Variables

- `CHECKPOINT_AUTO_CONFIRM=1` : Automatically answer "yes" to all interactive prompts

### Timeout Protection

All interactive prompts have built-in timeouts to prevent script hanging:
- Restore confirmation: 30-second timeout
- Directory creation: 30-second timeout
- Checkpoint ID selection: 60-second timeout

### Non-Interactive Usage Tips

```bash
# Create automatic backup with timestamp in filename
CHECKPOINT_AUTO_CONFIRM=1 checkpoint -s "auto-$(date +%Y%m%d)"

# Automated restore with explicit parameters
CHECKPOINT_AUTO_CONFIRM=1 checkpoint --restore --from 20250430_091429 --to /path/to/restore

# Regular pruning as part of maintenance scripts
checkpoint --prune-only --keep 10
```

## Default Exclusions

These patterns are automatically excluded from backups:
- Backup directory itself (prevents recursion)
- `.gudang/`, `temp/`, `.temp/`, `tmp/` directories
- Temporary files: `*~` and `~*`

## System Requirements

- **Core Dependencies**: `rsync`, `find`, and `stat` commands
- **Optional Dependencies**:
  - `hardlink`: For space-efficient backups
  - `delta` or `colordiff`: For enhanced diff visualization
- **Permissions**: Root/sudo access for restricted directories (optional with `--no-sudo`)
- **Remote Operations**: SSH access (only needed for remote features)

## License

[GPL-3.0 License](LICENSE)