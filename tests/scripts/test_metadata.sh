#\!/usr/bin/env bash
set -euo pipefail

display_metadata() {
  local cp_dir="$1"
  local metadata_file="$cp_dir/.metadata"
  
  # Check if metadata file exists
  if [ \! -f "$metadata_file" ]; then
    echo "No metadata available for checkpoint: $(basename "$cp_dir")"
    return 1
  fi
  
  # Get checkpoint name
  local cp_name=$(basename "$cp_dir")
  
  # Format and display metadata
  echo "Metadata for checkpoint: $cp_name"
  echo "----------------------------------------"
  
  # Read and display metadata values
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    if [[ "$key" == \#* || -z "$key" ]]; then
      continue
    fi
    
    # Format key for display
    local formatted_key=$(echo "$key"  < /dev/null |  tr '[:upper:]' '[:lower:]' | sed 's/\(.\)/\u\1/')
    
    # Special formatting for certain fields
    case "$key" in
      DESCRIPTION)
        echo "Description: $value"
        ;;
      CREATED)
        echo "Created on: $value"
        ;;
      HOST)
        echo "Source host: $value"
        ;;
      SYSTEM)
        echo "Source system: $value"
        ;;
      USER)
        echo "Created by: $value"
        ;;
      VERSION)
        echo "Checkpoint version: $value"
        ;;
      *)
        echo "$formatted_key: $value"
        ;;
    esac
  done < "$metadata_file"
  
  echo "----------------------------------------"
  return 0
}

# Use the function
display_metadata "$1"
