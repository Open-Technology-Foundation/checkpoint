#!/usr/bin/env bash
# install.sh - Checkpoint installer with dependency management
#
# One-liner installation:
#   curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/checkpoint/main/install.sh | bash
#   INSTALL_DIR=~/.local/bin bash install.sh  # Custom location
#
# Environment variables:
#   INSTALL_DIR    - Installation directory (default: /usr/local/bin)
#   MAN_DIR        - Man page directory (default: /usr/local/share/man/man1)
#   COMPLETION_DIR - Bash completion directory (default: /usr/share/bash-completion/completions)
#   REPO_URL       - Repository URL for downloads
#   BRANCH         - Git branch to download from (default: main)

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
MAN_DIR="${MAN_DIR:-/usr/local/share/man/man1}"
COMPLETION_DIR="${COMPLETION_DIR:-/usr/share/bash-completion/completions}"
REPO_URL="${REPO_URL:-https://github.com/Open-Technology-Foundation/checkpoint}"
BRANCH="${BRANCH:-main}"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Messaging functions
info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die() { error "$*"; exit 1; }

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# detect_os: Identify the operating system for package manager selection
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

# Download checkpoint script and manpage
download_checkpoint() {
  local temp_dir
  temp_dir=$(mktemp -d)
  cd "$temp_dir" || die "Failed to create temporary directory"

  info "Downloading checkpoint..."

  # Try curl first, then wget
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${REPO_URL}/raw/${BRANCH}/checkpoint" -o checkpoint || \
      die "Failed to download checkpoint"
    curl -fsSL "${REPO_URL}/raw/${BRANCH}/checkpoint.1" -o checkpoint.1 || \
      warn "Could not download manpage (will skip manpage installation)"
    curl -fsSL "${REPO_URL}/raw/${BRANCH}/checkpoint.bash_completion" -o checkpoint.bash_completion || \
      warn "Could not download bash completion (will skip completion installation)"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "${REPO_URL}/raw/${BRANCH}/checkpoint" -O checkpoint || \
      die "Failed to download checkpoint"
    wget -q "${REPO_URL}/raw/${BRANCH}/checkpoint.1" -O checkpoint.1 || \
      warn "Could not download manpage (will skip manpage installation)"
    wget -q "${REPO_URL}/raw/${BRANCH}/checkpoint.bash_completion" -O checkpoint.bash_completion || \
      warn "Could not download bash completion (will skip completion installation)"
  else
    die "Neither curl nor wget found. Please install one of them."
  fi

  # Verify download
  if [[ ! -f checkpoint ]] || [[ ! -s checkpoint ]]; then
    die "Downloaded file is empty or missing"
  fi

  # Make executable
  chmod +x checkpoint

  # Only output the directory path to stdout
  echo "$temp_dir"
}

# Install man page from downloaded checkpoint.1
install_manpage() {
  local checkpoint_path="$1"
  local temp_dir
  temp_dir=$(dirname "$checkpoint_path")
  local manpage="$temp_dir/checkpoint.1"

  # Check if manpage was downloaded
  if [[ ! -f "$manpage" ]]; then
    warn "Man page not available, skipping installation"
    return 0
  fi

  # Install man page
  if check_root || [[ -w "$MAN_DIR" ]]; then
    info "Installing man page to $MAN_DIR..."
    mkdir -p "$MAN_DIR"
    cp "$manpage" "$MAN_DIR/checkpoint.1"

    # Update man database if available
    if command -v mandb >/dev/null 2>&1; then
      mandb -q || true
    elif command -v makewhatis >/dev/null 2>&1; then
      makewhatis "$MAN_DIR" || true
    fi
  else
    warn "Cannot install man page to $MAN_DIR (no write permission)"
    warn "To install manually: sudo cp $manpage $MAN_DIR/"
  fi
}

# Install checkpoint script
install_checkpoint() {
  local checkpoint_path="$1"
  
  # Check if we can write to install directory
  if check_root || [ -w "$INSTALL_DIR" ]; then
    # Remove any existing checkpoint files/symlinks
    if [ -e "$INSTALL_DIR/checkpoint" ] || [ -L "$INSTALL_DIR/checkpoint" ]; then
      info "Removing existing checkpoint at $INSTALL_DIR/checkpoint..."
      rm -f "$INSTALL_DIR/checkpoint"
    fi
    
    if [ -e "$INSTALL_DIR/chkpoint" ] || [ -L "$INSTALL_DIR/chkpoint" ]; then
      info "Removing existing chkpoint symlink at $INSTALL_DIR/chkpoint..."
      rm -f "$INSTALL_DIR/chkpoint"
    fi
    
    info "Installing checkpoint to $INSTALL_DIR..."
    cp "$checkpoint_path" "$INSTALL_DIR/checkpoint"
    chmod +x "$INSTALL_DIR/checkpoint"
    
    # Create symlink for shorter command
    ln -sf "$INSTALL_DIR/checkpoint" "$INSTALL_DIR/chkpoint" || true
  else
    die "Cannot install to $INSTALL_DIR. Please run with sudo or set INSTALL_DIR to a writable location"
  fi
}

# Install bash completion from downloaded file
install_completion() {
  local checkpoint_path="$1"
  local temp_dir
  temp_dir=$(dirname "$checkpoint_path")
  local completion="$temp_dir/checkpoint.bash_completion"

  # Check if completion was downloaded
  if [[ ! -f "$completion" ]]; then
    warn "Bash completion not available, skipping installation"
    return 0
  fi

  # Install completion file
  if check_root || [[ -w "$COMPLETION_DIR" ]]; then
    info "Installing bash completion to $COMPLETION_DIR..."
    mkdir -p "$COMPLETION_DIR"
    cp "$completion" "$COMPLETION_DIR/checkpoint"

    # Create symlink for chkpoint alias
    ln -sf "$COMPLETION_DIR/checkpoint" "$COMPLETION_DIR/chkpoint" 2>/dev/null || true
  else
    warn "Cannot install bash completion to $COMPLETION_DIR (no write permission)"
    warn "To install manually: sudo cp $completion $COMPLETION_DIR/checkpoint"
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
  COMPLETION_DIR       Installation directory for bash completion
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

  # Install bash completion
  install_completion "$checkpoint_path"

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

#fin