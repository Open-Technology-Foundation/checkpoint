#!/usr/bin/env bash
# Checkpoint installation script
# Suitable for one-liner installation:
# curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/checkpoint/main/install.sh | bash

set -euo pipefail

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
MAN_DIR="${MAN_DIR:-/usr/local/share/man/man1}"
REPO_URL="${REPO_URL:-https://github.com/YOUR_REPO/checkpoint}"
BRANCH="${BRANCH:-main}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die() { error "$*"; exit 1; }

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/debian_version ]; then
      echo "debian"
    elif [ -f /etc/redhat-release ]; then
      echo "redhat"
    elif [ -f /etc/arch-release ]; then
      echo "arch"
    elif [ -f /etc/alpine-release ]; then
      echo "alpine"
    else
      echo "linux"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

# Check if running as root
check_root() {
  if [ "$EUID" -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# Install dependencies based on OS
install_dependencies() {
  local os=$(detect_os)
  info "Detected OS: $os"
  
  # Check for required commands
  local missing_deps=()
  
  # Core dependencies
  for cmd in rsync find stat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done
  
  # Optional but recommended
  local optional_deps=()
  if ! command -v hardlink >/dev/null 2>&1; then
    optional_deps+=("hardlink")
  fi
  
  if [ ${#missing_deps[@]} -eq 0 ]; then
    info "All required dependencies are already installed"
  else
    warn "Missing required dependencies: ${missing_deps[*]}"
    
    case "$os" in
      debian)
        info "Installing dependencies using apt-get..."
        if check_root; then
          apt-get update -qq
          apt-get install -y rsync findutils coreutils
          [ ${#optional_deps[@]} -gt 0 ] && apt-get install -y hardlink || true
        else
          die "Please run with sudo to install dependencies"
        fi
        ;;
      redhat)
        info "Installing dependencies using yum/dnf..."
        if check_root; then
          if command -v dnf >/dev/null 2>&1; then
            dnf install -y rsync findutils coreutils
            [ ${#optional_deps[@]} -gt 0 ] && dnf install -y hardlink || true
          else
            yum install -y rsync findutils coreutils
            [ ${#optional_deps[@]} -gt 0 ] && yum install -y hardlink || true
          fi
        else
          die "Please run with sudo to install dependencies"
        fi
        ;;
      arch)
        info "Installing dependencies using pacman..."
        if check_root; then
          pacman -Sy --noconfirm rsync findutils coreutils
          [ ${#optional_deps[@]} -gt 0 ] && pacman -S --noconfirm hardlink || true
        else
          die "Please run with sudo to install dependencies"
        fi
        ;;
      alpine)
        info "Installing dependencies using apk..."
        if check_root; then
          apk add --no-cache rsync findutils coreutils
          [ ${#optional_deps[@]} -gt 0 ] && apk add --no-cache hardlink || true
        else
          die "Please run with sudo to install dependencies"
        fi
        ;;
      macos)
        if command -v brew >/dev/null 2>&1; then
          info "Installing dependencies using Homebrew..."
          brew install rsync findutils coreutils
          [ ${#optional_deps[@]} -gt 0 ] && brew install hardlink || true
        else
          warn "Homebrew not found. Please install dependencies manually:"
          warn "  brew install rsync findutils coreutils hardlink"
        fi
        ;;
      *)
        warn "Unknown OS. Please install these dependencies manually:"
        warn "  Required: rsync find stat"
        warn "  Optional: hardlink"
        ;;
    esac
  fi
  
  # Install optional dependencies notice
  if [ ${#optional_deps[@]} -gt 0 ]; then
    warn "Optional dependencies not found: ${optional_deps[*]}"
    warn "Checkpoint will work without them but with reduced functionality"
  fi
}

# Download checkpoint script
download_checkpoint() {
  local temp_dir=$(mktemp -d)
  cd "$temp_dir" || die "Failed to create temporary directory"
  
  info "Downloading checkpoint..."
  
  # Try curl first, then wget
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${REPO_URL}/raw/${BRANCH}/checkpoint" -o checkpoint || \
      die "Failed to download checkpoint"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "${REPO_URL}/raw/${BRANCH}/checkpoint" -O checkpoint || \
      die "Failed to download checkpoint"
  else
    die "Neither curl nor wget found. Please install one of them."
  fi
  
  # Verify download
  if [ ! -f checkpoint ] || [ ! -s checkpoint ]; then
    die "Downloaded file is empty or missing"
  fi
  
  # Make executable
  chmod +x checkpoint
  
  echo "$temp_dir"
}

# Generate and install man page
install_manpage() {
  local checkpoint_path="$1"
  local temp_dir=$(dirname "$checkpoint_path")
  
  info "Generating man page..."
  
  # Create man page content
  cat > "$temp_dir/checkpoint.1" << 'EOF'
.TH CHECKPOINT 1 "$(date +'%B %Y')" "checkpoint 1.5.0" "User Commands"
.SH NAME
checkpoint \- create and restore checkpoint backups
.SH SYNOPSIS
.B checkpoint
[\fIOPTIONS\fR] [\fIdirectory\fR]
.br
.B checkpoint
\-\-list [\fIOPTIONS\fR] [\fIdirectory\fR]
.br
.B checkpoint
\-\-restore [\fIRESTORE_OPTIONS\fR] [\fIdirectory\fR]
.SH DESCRIPTION
Checkpoint creates timestamped backup snapshots of a directory with features including
metadata tracking, remote operations, atomic backups, and space-efficient hardlinking.
.PP
Default backup location: /var/backups/DIR_NAME/TIMESTAMP[_SUFFIX]
.PP
Automatically excludes: backup_dir, .gudang/, temp/, .temp/, tmp/, *~, ~*
.SH OPTIONS
.TP
.BR \-d ", " \-\-backup\-dir " " \fIDIR\fR
Backup directory for checkpoints (default: /var/backups/DIR_NAME)
.TP
.BR \-s ", " \-\-suffix " " \fISUF\fR
Optional suffix to add to checkpoint name
.TP
.BR \-n ", " \-\-no\-hardlink
Do not hardlink to previous backup
.TP
.BR \-\-hardlink
Hardlink to previous backup (default if hardlink command available)
.TP
.BR \-q ", " \-\-quiet
Quiet mode, minimal output
.TP
.BR \-v ", " \-\-verbose
Verbose output (default)
.TP
.BR \-l ", " \-\-list
List existing checkpoints instead of creating new one
.TP
.BR \-x ", " \-\-exclude " " \fIPATTERN\fR
Exclude files/directories matching pattern (can be used multiple times)
.TP
.BR \-\-no\-sudo
Do not attempt to use sudo for privilege escalation
.TP
.BR \-\-debug
Show debug information during operation
.TP
.BR \-\-verify
Verify backup integrity after creation
.TP
.BR \-\-no\-lock
Disable lockfile mechanism (dangerous - allows concurrent operations)
.TP
.BR \-\-lock\-timeout " " \fISECONDS\fR
Timeout for acquiring lock (default: 300 seconds)
.TP
.BR \-\-force\-unlock
Force removal of stale locks before proceeding
.SH RESTORE OPTIONS
.TP
.BR \-r ", " \-\-restore
Restore from checkpoint backup
.TP
.BR \-f ", " \-\-from " " \fIID\fR
Source checkpoint to restore from (timestamp or name)
.TP
.BR \-t ", " \-\-to " " \fIDIR\fR
Target directory to restore to
.TP
.BR \-\-dry\-run
Show what would be restored without making changes
.TP
.BR \-\-diff
Show differences between current files and checkpoint
.TP
.BR \-\-files " " \fIPATTERN\fR
Specific files or patterns to restore (can be used multiple times)
.SH METADATA OPTIONS
.TP
.BR \-\-metadata
Perform metadata operations
.TP
.BR \-\-show " " \fIID\fR
Show metadata for checkpoint ID
.TP
.BR \-\-update " " \fIID\fR
Update metadata for checkpoint ID
.TP
.BR \-\-find " " \fIPATTERN\fR
Find checkpoints matching metadata pattern
.TP
.BR \-\-desc " " \fITEXT\fR
Set checkpoint description
.TP
.BR \-\-system " " \fINAME\fR
Set source system name
.TP
.BR \-\-tag " " \fIKEY=VALUE\fR
Add tag to checkpoint metadata (can be used multiple times)
.SH EXAMPLES
.PP
Create checkpoint of current directory:
.RS
checkpoint
.RE
.PP
Create checkpoint with description:
.RS
checkpoint -s "before-refactor" --desc "Stable version before API changes"
.RE
.PP
List all checkpoints:
.RS
checkpoint --list
.RE
.PP
Restore from specific checkpoint:
.RS
checkpoint --restore --from 20250430_091429
.RE
.PP
Compare two checkpoints:
.RS
checkpoint --from 20250430_091429 --compare-with 20250430_101530
.RE
.SH ENVIRONMENT
.TP
.B CHECKPOINT_AUTO_CONFIRM
If set, automatically confirm prompts without user interaction
.SH FILES
.TP
.I /var/backups/*/
Default location for checkpoint backups
.TP
.I .checkpoint.lock
Lockfile to prevent concurrent operations
.TP
.I .metadata
Metadata file within each checkpoint
.SH EXIT STATUS
.TP
.B 0
Success
.TP
.B 1
General error
.TP
.B 2
Invalid arguments
.SH AUTHOR
Written by the checkpoint contributors.
.SH SEE ALSO
.BR rsync (1),
.BR hardlink (1)
EOF
  
  # Install man page
  if check_root || [ -w "$MAN_DIR" ]; then
    info "Installing man page to $MAN_DIR..."
    mkdir -p "$MAN_DIR"
    cp "$temp_dir/checkpoint.1" "$MAN_DIR/checkpoint.1"
    
    # Update man database if available
    if command -v mandb >/dev/null 2>&1; then
      mandb -q || true
    elif command -v makewhatis >/dev/null 2>&1; then
      makewhatis "$MAN_DIR" || true
    fi
  else
    warn "Cannot install man page to $MAN_DIR (no write permission)"
    warn "To install manually: sudo cp $temp_dir/checkpoint.1 $MAN_DIR/"
  fi
}

# Install checkpoint script
install_checkpoint() {
  local checkpoint_path="$1"
  
  # Check if we can write to install directory
  if check_root || [ -w "$INSTALL_DIR" ]; then
    info "Installing checkpoint to $INSTALL_DIR..."
    cp "$checkpoint_path" "$INSTALL_DIR/checkpoint"
    chmod +x "$INSTALL_DIR/checkpoint"
    
    # Create symlink for shorter command
    ln -sf "$INSTALL_DIR/checkpoint" "$INSTALL_DIR/chkpoint" || true
  else
    die "Cannot install to $INSTALL_DIR. Please run with sudo or set INSTALL_DIR to a writable location"
  fi
}

# Verify installation
verify_installation() {
  info "Verifying installation..."
  
  # Check if checkpoint is in PATH
  if command -v checkpoint >/dev/null 2>&1; then
    local installed_version=$(checkpoint --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    info "Checkpoint $installed_version successfully installed!"
    info "Location: $(command -v checkpoint)"
    
    # Check man page
    if man -w checkpoint >/dev/null 2>&1; then
      info "Man page installed. Use 'man checkpoint' for documentation"
    fi
    
    return 0
  else
    error "Installation verification failed"
    error "You may need to add $INSTALL_DIR to your PATH"
    return 1
  fi
}

# Main installation flow
main() {
  echo "==================================="
  echo "Checkpoint Installation Script"
  echo "==================================="
  echo
  
  # Check for help
  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help           Show this help message
  --install-dir DIR    Set installation directory (default: $INSTALL_DIR)
  --man-dir DIR        Set man page directory (default: $MAN_DIR)
  --skip-deps          Skip dependency installation
  --branch BRANCH      Install from specific git branch (default: $BRANCH)

ENVIRONMENT VARIABLES:
  INSTALL_DIR          Installation directory for checkpoint script
  MAN_DIR              Installation directory for man page
  REPO_URL             Git repository URL
  BRANCH               Git branch to install from

EXAMPLES:
  # Standard installation
  curl -fsSL https://example.com/install.sh | bash
  
  # Install to custom location
  curl -fsSL https://example.com/install.sh | INSTALL_DIR=~/.local/bin bash
  
  # Install without sudo (to user directory)
  curl -fsSL https://example.com/install.sh | INSTALL_DIR=~/.local/bin MAN_DIR=~/.local/share/man/man1 bash
EOF
    exit 0
  fi
  
  # Parse arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --install-dir)
        INSTALL_DIR="$2"
        shift 2
        ;;
      --man-dir)
        MAN_DIR="$2"
        shift 2
        ;;
      --skip-deps)
        SKIP_DEPS=1
        shift
        ;;
      --branch)
        BRANCH="$2"
        shift 2
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
  
  # Install dependencies
  if [ "${SKIP_DEPS:-0}" -eq 0 ]; then
    install_dependencies
  else
    info "Skipping dependency installation"
  fi
  
  # Download checkpoint
  local temp_dir=$(download_checkpoint)
  local checkpoint_path="$temp_dir/checkpoint"
  
  # Install checkpoint
  install_checkpoint "$checkpoint_path"
  
  # Install man page
  install_manpage "$checkpoint_path"
  
  # Cleanup
  rm -rf "$temp_dir"
  
  # Verify
  if verify_installation; then
    echo
    info "Installation complete!"
    info "Run 'checkpoint --help' to get started"
  else
    die "Installation failed"
  fi
}

# Run main function
main "$@"