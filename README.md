# Checkpoint

A simple, reliable utility for creating codebase snapshots (checkpoints) during development.

## Overview

The `checkpoint` script creates backup snapshots of a directory, storing them in a timestamped directory structure. It's designed for developers who want to quickly save the current state of their codebase before making significant changes. The tool provides a simple way to create, list, and manage code snapshots.

## Features

- Creates timestamped snapshots of directories
- Lists existing checkpoints with sizes and totals
- Excludes backup directories to prevent recursive copying
- Configurable backup destination
- Optional descriptive suffixes for backups
- Quiet mode for use in scripts and automation
- Cross-platform support (Linux and macOS)
- Uses `rsync` for efficient copying

## Installation

Simply clone this repository or download the `checkpoint` script. Make it executable:

```bash
chmod +x checkpoint
```

For system-wide installation:

```bash
sudo cp checkpoint /usr/local/bin/
```

## Usage

```
checkpoint [OPTIONS] [directory]
```

### Options

- `-d, --backup-dir DIR` : Backup directory for checkpoints (default: /var/backups/DIR_NAME)
- `-s, --suffix SUF` : Optional suffix to add to checkpoint directory name (alphanumeric, dots, underscores and hyphens only)
- `-q, --quiet` : Quiet mode with minimal output
- `-v, --verbose` : Verbose output (default)
- `-l, --list` : List existing checkpoints instead of creating a new one
- `-V, --version` : Print version and exit
- `-h, --help` : Display help information

### Examples

Create checkpoint backup of current directory:
```bash
checkpoint
```

Create checkpoint backup of a specific directory with custom destination:
```bash
checkpoint -d ~/backups/myproject ~/myscript
```

Create checkpoint with a descriptive suffix:
```bash
checkpoint -s "before-api-refactor"
```

Create checkpoint in quiet mode:
```bash
checkpoint -q
```

List existing checkpoints for the current directory:
```bash
checkpoint --list
```

## Backup Format

Backups are stored in the following format:
```
<destination>/<timestamp>[_<suffix>]/
```

Example:
```
/var/backups/project_name/20250310_143022_before-api-refactor/
```

## Requirements

- Requires root or sudo access to maintain proper file ownership
- Uses `rsync`, `find`, and `stat` commands (included in most Linux/Unix systems)
- Excludes directories: backup_dir, .gudang/, temp/, .temp/, tmp/
- Excludes files: *~ and ~*

## Sample List Output

Listing checkpoints with `checkpoint --list`:

```
Checkpoints for /path/to/source in /var/backups/source_dir:
----------------------------------------
20250313_170443_refactor            6.0K
20250313_170035                      30K
20250313_170019                      30K
20250313_164701                      30K
----------------------------------------
Total backups: 4   Total size: 96K
```

## License

[GPL-3.0 License](LICENSE)