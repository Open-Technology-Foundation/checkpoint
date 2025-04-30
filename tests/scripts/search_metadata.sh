#\!/usr/bin/env bash
set -euo pipefail

backup_dir="$1"
search_key="$2"
search_value="$3"

echo "Searching for backups with $search_key=$search_value in $backup_dir:"
echo "-------------------------------------------------------"

found=0
# Find all checkpoint directories
while IFS= read -r dir; do
  # Check if metadata file exists
  metadata_file="$dir/.metadata"
  if [ \! -f "$metadata_file" ]; then
    continue
  fi
  
  # Check if metadata contains key=value
  if grep -q "^$search_key=$search_value$" "$metadata_file"; then
    cp_name=$(basename "$dir")
    desc=$(grep "^DESCRIPTION=" "$metadata_file" 2>/dev/null  < /dev/null |  cut -d= -f2- || echo "(no description)")
    echo "Match: $cp_name - $desc"
    found=$((found + 1))
  fi
done < <(find "$backup_dir" -maxdepth 1 -type d -name "20*" | sort -r)

if [ $found -eq 0 ]; then
  echo "No matching checkpoints found."
else
  echo "-------------------------------------------------------"
  echo "$found checkpoint(s) matched the search criteria."
fi
