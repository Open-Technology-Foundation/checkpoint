#!/usr/bin/env bash
# update_metadata.sh - Update or add metadata fields to a checkpoint
#
# Usage: ./update_metadata.sh <checkpoint_dir> <key> <value>
#
# Updates an existing metadata key or adds a new one. Keys must be
# alphanumeric with underscores only (e.g., DESCRIPTION, TAG, CUSTOM_FIELD).

set -euo pipefail

# update_metadata: Modify or add a metadata key-value pair
# Args: $1 - checkpoint directory, $2 - key name, $3 - value
# Returns: 0 on success, 1 on error
update_metadata() {
  local cp_dir="$1"
  local key="$2"
  local value="$3"
  local metadata_file="$cp_dir/.metadata"

  # Check if metadata file exists
  if [[ ! -f "$metadata_file" ]]; then
    echo "No metadata file found for checkpoint: $(basename "$cp_dir")"
    return 1
  fi

  # Validate key format (alphanumeric and underscores only)
  if ! [[ "$key" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Invalid metadata key format: $key"
    return 1
  fi

  # Update or append metadata
  if grep -q "^$key=" "$metadata_file"; then
    # Key exists - update it (cross-platform sed)
    if sed -i "s|^$key=.*|$key=$value|" "$metadata_file" 2>/dev/null; then
      : # GNU sed succeeded
    else
      # BSD/macOS fallback
      sed "s|^$key=.*|$key=$value|" "$metadata_file" > "$metadata_file.tmp" &&
        mv "$metadata_file.tmp" "$metadata_file"
    fi
  else
    # Key doesn't exist - append it
    echo "$key=$value" >> "$metadata_file"
  fi

  echo "Updated metadata key '$key' for checkpoint: $(basename "$cp_dir")"
  return 0
}

# Check arguments
if (( $# != 3 )); then
  echo "Usage: $0 <checkpoint_dir> <key> <value>"
  exit 1
fi

update_metadata "$1" "$2" "$3"

#fin
