#\!/usr/bin/env bash
set -euo pipefail

# Function to update metadata
update_metadata() {
  local cp_dir="$1"
  local key="$2"
  local value="$3"
  local metadata_file="$cp_dir/.metadata"
  
  # Check if metadata file exists
  if [ \! -f "$metadata_file" ]; then
    echo "No metadata file found for checkpoint: $(basename "$cp_dir")"
    return 1
  fi
  
  # Validate key format
  if \! [[ "$key" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Invalid metadata key format: $key"
    return 1
  fi
  
  # Update metadata file
  if grep -q "^$key=" "$metadata_file"; then
    # Key exists, update it
    sed -i "s < /dev/null | ^$key=.*|$key=$value|" "$metadata_file" 2>/dev/null
    
    # Handle BSD/macOS sed which doesn't support -i without extension
    if [[ $? -ne 0 ]]; then
      sed "s|^$key=.*|$key=$value|" "$metadata_file" > "$metadata_file.tmp" && 
        mv "$metadata_file.tmp" "$metadata_file"
    fi
  else
    # Key doesn't exist, append it
    echo "$key=$value" >> "$metadata_file"
  fi
  
  echo "Updated metadata key '$key' for checkpoint: $(basename "$cp_dir")"
  return 0
}

# Check arguments
if [ $# -ne 3 ]; then
  echo "Usage: $0 <checkpoint_dir> <key> <value>"
  exit 1
fi

# Update metadata
update_metadata "$1" "$2" "$3"
