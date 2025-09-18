#!/usr/bin/env bash
# Create a man page for checkpoint utility from the README.md file
#shellcheck disable=SC2016
set -euo pipefail

# Check for dependencies
check_dependencies() {
  local deps=("pandoc" "sudo")
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      echo "Error: Required command '$dep' not found." >&2
      echo "Please install it and try again." >&2
      if [ "$dep" = "pandoc" ]; then
        echo "You can install pandoc with:" >&2
        echo "  sudo apt install pandoc    # Debian/Ubuntu" >&2
        echo "  sudo yum install pandoc    # RHEL/CentOS" >&2
        echo "  brew install pandoc        # macOS" >&2
      fi
      exit 1
    fi
  done
}

# Get script directory for relative paths
get_script_dir() {
  local script_path

  if command -v readlink >/dev/null 2>&1 && readlink -f -- "$0" >/dev/null 2>&1; then
    # Linux with GNU readlink
    script_path=$(dirname "$(readlink -f -- "$0")")
  elif command -v realpath >/dev/null 2>&1; then
    # Systems with realpath command
    script_path=$(dirname "$(realpath -- "$0")")
  else
    # Fallback for systems without readlink/realpath
    script_path=$(cd "$(dirname "$0")" && pwd)
  fi

  echo "$script_path"
}

# Main function to generate man page
generate_manpage() {
  local script_dir readme manpage_dir tmp_md tmp_man section_num
  
  script_dir=$(get_script_dir)
  readme="$script_dir/README.md"
  section_num=1
  manpage_dir="/usr/local/share/man/man$section_num"
  tmp_md=$(mktemp)
  tmp_man=$(mktemp)
  
  echo "Creating man page from $readme..."
  
  # Check if README.md exists
  if [ ! -f "$readme" ]; then
    echo "Error: README.md not found at $readme" >&2
    exit 1
  fi
  
  # Create a temporary file with proper man page metadata
  cat > "$tmp_md" << EOF
% CHECKPOINT($section_num) | System Administration Commands
% 
% $(date "+%B %d, %Y")

# NAME

checkpoint - create and restore timestamped snapshots of code directories

# SYNOPSIS

**checkpoint** [OPTIONS] [directory]

**checkpoint** --list [OPTIONS] [directory]

**checkpoint** --restore [RESTORE_OPTIONS] [directory]

EOF
  
  # Append the README content, skipping the title and first few lines
  # that are already covered in the header
  awk 'NR > 7' "$readme" >> "$tmp_md"
  
  # Convert markdown to man page format
  echo "Converting markdown to man page format..."
  pandoc "$tmp_md" -s -t man -o "$tmp_man"
  
  # Create the man directory if it doesn't exist
  if [ ! -d "$manpage_dir" ]; then
    echo "Creating man page directory $manpage_dir..."
    sudo mkdir -p "$manpage_dir"
  fi
  
  # Install the man page
  echo "Installing man page to $manpage_dir/checkpoint.$section_num..."
  sudo cp "$tmp_man" "$manpage_dir/checkpoint.$section_num"
  
  # Set proper permissions (world-readable)
  sudo chmod 644 "$manpage_dir/checkpoint.$section_num"
  
  # Update man database
  echo "Updating man database..."
  if command -v mandb &>/dev/null; then
    sudo mandb >/dev/null 2>&1
  elif command -v makewhatis &>/dev/null; then
    sudo makewhatis >/dev/null 2>&1
  fi
  
  # Clean up temporary files
  rm -f "$tmp_md" "$tmp_man"
  
  echo "Man page installation complete."
  echo "You can now view the man page with: man checkpoint"
}

# Main execution
main() {
  check_dependencies
  generate_manpage
}

main "$@"

#fin
