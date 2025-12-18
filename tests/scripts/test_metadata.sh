#!/usr/bin/env bash
# test_metadata.sh - Display metadata for a checkpoint directory
#
# Usage: ./test_metadata.sh <checkpoint_directory>
#
# Reads and formats the .metadata file from a checkpoint.

set -euo pipefail

display_metadata() {
  local cp_dir="$1"
  local metadata_file="$cp_dir/.metadata"

  if [[ ! -f "$metadata_file" ]]; then
    echo "No metadata available for checkpoint: $(basename "$cp_dir")"
    return 1
  fi

  local cp_name
  cp_name=$(basename "$cp_dir")

  echo "Metadata for checkpoint: $cp_name"
  echo "----------------------------------------"

  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" == \#* || -z "$key" ]] && continue

    case "$key" in
      DESCRIPTION) echo "Description: $value" ;;
      CREATED)     echo "Created on: $value" ;;
      HOST)        echo "Source host: $value" ;;
      SYSTEM)      echo "Source system: $value" ;;
      USER)        echo "Created by: $value" ;;
      VERSION)     echo "Checkpoint version: $value" ;;
      *)           echo "$key: $value" ;;
    esac
  done < "$metadata_file"

  echo "----------------------------------------"
  return 0
}

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <checkpoint_directory>"
  exit 1
fi

display_metadata "$1"

#fin
