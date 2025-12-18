# Checkpoint: Purpose, Functionality, and Usage

## Purpose

**Checkpoint** is a cross-platform Bash utility for creating, managing, and restoring timestamped directory snapshots. It bridges the gap between informal backup practices and enterprise-grade snapshot management.

### Target Users
- **Developers**: Create recovery points before risky code changes
- **System Administrators**: Manage configuration file backups with metadata
- **DevOps Engineers**: Automate backups in CI/CD pipelines with timeout safeguards

### Core Problem Solved
Provides simple commands for complex backup/restore operations with:
- Reliable recovery points during iterative development
- Visual change tracking between snapshots
- Cross-platform consistency (Linux and macOS)
- Automation-ready non-interactive operation

---

## Key Functionality

### 1. Backup Operations
| Feature | Description |
|---------|-------------|
| **Smart Snapshots** | Timestamped backups (YYYYMMDD_HHMMSS format) with automatic exclusions |
| **Atomic Operations** | Creates backups in `.tmp.*` directories, renames atomically on success |
| **Hardlinking** | Links unchanged files between versions for 90%+ space savings |
| **Rotation** | Keep N most recent (`--keep`) or remove older than N days (`--age`) |
| **Verification** | Checksum-based integrity verification (`--verify`) |

### 2. Restore Operations
| Feature | Description |
|---------|-------------|
| **Full/Selective** | Restore entire directories or specific file patterns (`--files`) |
| **Preview Mode** | Dry-run to see what would change (`--dry-run`) |
| **Diff Mode** | Compare current files with checkpoint before restoring (`--diff`) |
| **Target Override** | Restore to different directory (`--to DIR`) |

### 3. Comparison Features
| Feature | Description |
|---------|-------------|
| **Checkpoint vs Current** | Compare working directory with any checkpoint |
| **Checkpoint vs Checkpoint** | Compare two historical snapshots (`--compare-with`) |
| **Detailed View** | Show file content differences (`--detailed`) |
| **Pattern Filtering** | Compare only matching files (`--files "*.js"`) |

### 4. Metadata System
| Feature | Description |
|---------|-------------|
| **Descriptions** | Attach human-readable notes to checkpoints (`--desc`) |
| **Tags** | Add searchable key-value metadata (`--tag KEY=VALUE`) |
| **Search** | Find checkpoints by metadata patterns (`--find PATTERN`) |
| **Update** | Modify metadata on existing checkpoints (`--update ID --set`) |

### 5. Remote Operations
| Feature | Description |
|---------|-------------|
| **SSH-Based** | Create/restore backups on remote hosts via secure SSH |
| **Timeout Protection** | Configurable SSH timeouts (`--timeout SECONDS`) |
| **Hardened Security** | Secure default SSH options for remote operations |

### 6. Concurrency Protection
| Feature | Description |
|---------|-------------|
| **Lockfile Mechanism** | Directory-based locking prevents parallel corruption |
| **PID Verification** | Ownership tracking with automatic stale lock cleanup |
| **Force Unlock** | Manual removal of stuck locks (`--force-unlock`) |

---

## Architecture Overview

```
checkpoint (main script ~2400 lines)
|
+-- Core Functions
|   +-- get_canonical_path()    # Cross-platform path resolution
|   +-- get_owner_info()        # Cross-platform ownership info
|   +-- calculate_checksum()    # SHA256/MD5/fallback checksums
|   +-- check_disk_space()      # Pre-backup space verification
|
+-- Locking Functions
|   +-- acquire_lock()          # Atomic mkdir-based locking
|   +-- release_lock()          # PID-verified lock release
|   +-- force_remove_lock()     # Manual stale lock removal
|
+-- Backup/Restore Functions
|   +-- verify_backup()         # Post-backup integrity check
|   +-- compare_files()         # Current vs checkpoint diff
|   +-- compare_checkpoints()   # Checkpoint vs checkpoint diff
|
+-- Metadata Functions
|   +-- metadata operations     # show/update/find checkpoint metadata
```

### Directory Structure
```
project/
+-- checkpoint              # Main executable (97KB)
+-- install.sh              # One-line installer with dependency detection
+-- create_manpage.sh       # Man page generator
+-- checkpoint.1            # Generated man page
+-- tests/
|   +-- test_checkpoint.bats  # Core functionality tests
|   +-- test_locking.bats     # Concurrency protection tests
|   +-- test_remote.bats      # Remote operation tests
|   +-- test_atomic.bats      # Atomic backup tests
|   +-- test_helper.bash      # BATS test utilities
|   +-- fixtures/             # Test data directories
```

---

## Usage Examples

### Basic Workflow

```bash
# Create checkpoint of current directory
checkpoint

# Create checkpoint with description
checkpoint -s "before-refactor" --desc "Stable baseline before API changes"

# List existing checkpoints
checkpoint --list

# Compare current state with latest checkpoint
checkpoint --restore --diff

# Restore latest checkpoint
checkpoint --restore
```

### Development Safety

```bash
# Before risky changes
checkpoint -s "pre-api-refactor" --desc "Stable baseline"

# After changes, compare
checkpoint --restore --diff

# If things went wrong, restore
checkpoint --restore --from 20250430_091429

# Selective restore (only JS files)
checkpoint --restore --files "*.js" --files "docs/*.md"
```

### System Administration

```bash
# Backup system configuration (as root)
sudo checkpoint -d /var/backups/system /etc

# Backup with rotation (keep 5 most recent)
checkpoint --keep 5

# Age-based cleanup (remove > 30 days old)
checkpoint --age 30
```

### Remote Operations

```bash
# Create backup on remote server
checkpoint --remote user@host:/path/to/backups

# List remote checkpoints
checkpoint --remote user@host:/path/to/backups --list

# Restore from remote
checkpoint --remote user@host:/path/to/backups --restore --from 20250430_091429
```

### CI/CD Integration

```bash
# Skip interactive prompts
export CHECKPOINT_AUTO_CONFIRM=1

# Create checkpoint with build number
checkpoint -s "build-${BUILD_NUMBER}"

# Set default backup directory
export CHECKPOINT_BACKUP_DIR=~/backups
checkpoint ~/myproject
```

---

## Command Reference

### Core Options
| Option | Description |
|--------|-------------|
| `-d, --backup-dir DIR` | Custom backup location |
| `-s, --suffix SUF` | Add suffix to checkpoint name |
| `-l, --list` | List existing checkpoints |
| `-q, --quiet` | Minimal output |
| `-v, --verbose` | Detailed output (default) |

### Backup Management
| Option | Description |
|--------|-------------|
| `--keep N` | Keep only N most recent backups |
| `--age DAYS` | Remove backups older than DAYS |
| `--verify` | Verify backup integrity |
| `--prune-only` | Only prune, don't create new backup |
| `--no-sudo` | Never escalate privileges |
| `--hardlink` | Enable space-efficient hardlinking |

### Restore and Compare
| Option | Description |
|--------|-------------|
| `--restore` | Restore from checkpoint |
| `--from ID` | Source checkpoint (timestamp or partial match) |
| `--to DIR` | Target restore directory |
| `--dry-run` | Preview changes without applying |
| `--diff` | Show differences before restoring |
| `--compare-with ID` | Compare two checkpoints |
| `--detailed` | Show file content differences |
| `--files PATTERN` | Selective file patterns |

### Concurrency Control
| Option | Description |
|--------|-------------|
| `--no-lock` | Disable locking (dangerous) |
| `--lock-timeout N` | Lock timeout in seconds (default: 300) |
| `--force-unlock` | Remove stale locks |

---

## Default Behavior

### Backup Directory Selection
| User Type | Default Location |
|-----------|------------------|
| Root/sudo | `/var/backups/DIR_NAME/` |
| Regular user | `~/.checkpoint/DIR_NAME/` |
| Custom | `$CHECKPOINT_BACKUP_DIR/DIR_NAME/` |

### Automatic Exclusions
- `.gudang/`, `temp/`, `.temp/`, `tmp/` directories
- Temporary files: `*~` and `~*`
- Backup directory itself (prevents recursion)
- Lock directories: `.checkpoint.lock/`
- Atomic temp directories: `.tmp.*`

---

## Dependencies

### Required
- `rsync` - File synchronization
- `find` - File discovery
- `stat` - File metadata

### Optional
- `hardlink` - Space-efficient backup storage
- `delta` or `colordiff` - Enhanced diff visualization
- `sha256sum`/`shasum` - Checksum verification
- SSH client - For remote operations

---

## Installation

### One-Line Install
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/install.sh | bash
```

### Manual Install
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/checkpoint -o checkpoint
chmod +x checkpoint
sudo cp checkpoint /usr/local/bin/
```

---

## Testing

```bash
# Run all tests
bats tests/test_checkpoint.bats

# Run specific test suites
bats tests/test_locking.bats     # Concurrency tests
bats tests/test_remote.bats      # Remote operation tests
bats tests/test_atomic.bats      # Atomic backup tests

# Lint code
shellcheck checkpoint
```

---

## Version Information

**Current Version**: 1.6.0

### Recent Changes
- **v1.6.0**: Full BCS compliance, standardized messaging with visual indicators
- **v1.5.0**: Atomic operations with temp directories and automatic cleanup
- **v1.4.0**: Lockfile concurrency protection with PID verification
- **v1.3.0**: Enhanced metadata management and remote operations

---

## Security Considerations

- **Input Validation**: Strict pattern matching prevents injection attacks
- **SSH Hardening**: Secure default options for remote operations
- **Path Protection**: Prevents directory traversal attacks
- **Privilege Management**: Smart sudo escalation with `--no-sudo` bypass
- **Atomic Operations**: No partial/corrupt backups on interruption

#fin
