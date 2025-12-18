#!/usr/bin/env bash
# search_metadata.sh - Search checkpoints by metadata key-value pairs
#
# Usage: ./search_metadata.sh <backup_directory> <key> <value>
#
# Searches all checkpoints in a backup directory for matching metadata.
# Useful for finding checkpoints by tag, host, user, or custom fields.

set -euo pipefail

backup_dir="$1"
search_key="$2"
search_value="$3"

echo "Searching for backups with $search_key=$search_value in $backup_dir:"
echo "-------------------------------------------------------"

declare -i found=0

# Find all checkpoint directories
while IFS= read -r dir; do
  metadata_file="$dir/.metadata"

  # Skip if no metadata file
  [[ ! -f "$metadata_file" ]] && continue

  # Check if metadata contains key=value
  if grep -q "^$search_key=$search_value$" "$metadata_file"; then
    cp_name=$(basename "$dir")
    desc=$(grep "^DESCRIPTION=" "$metadata_file" 2>/dev/null | cut -d= -f2- || echo "(no description)")
    echo "Match: $cp_name - $desc"
    (( found++ ))
  fi
done < <(find "$backup_dir" -maxdepth 1 -type d -name "20*" | sort -r)

if (( found == 0 )); then
  echo "No matching checkpoints found."
else
  echo "-------------------------------------------------------"
  echo "$found checkpoint(s) matched the search criteria."
fi

#fin
