#!/usr/bin/env bash
# ssh_test.sh - Test SSH connectivity for remote backup feature
#
# Usage: ./ssh_test.sh [host] [user]
#
# Tests SSH key-based authentication and rsync availability on remote host.

set -euo pipefail

HOST="${1:-okusi0}"
USER="${2:-${USER:-$(whoami)}}"

echo "Testing SSH connectivity to $USER@$HOST..."

if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$USER@$HOST" "echo 'Connection successful'" 2>/dev/null; then
  echo "✓ Connection successful!"
  echo "Checking rsync availability..."
  if ssh "$USER@$HOST" "command -v rsync" >/dev/null 2>&1; then
    echo "✓ rsync is available on remote host"
    echo "Remote backup feature should work correctly."
  else
    echo "✗ rsync not found on remote host"
    echo "Please install rsync on the remote host to use remote backup feature."
  fi
else
  echo "✗ SSH connection failed"
  echo
  echo "For remote backup to work, you need SSH key-based authentication set up."
  echo "Steps to set up SSH keys:"
  echo "1. Generate SSH key pair (if not already done):"
  echo "   ssh-keygen -t ed25519"
  echo
  echo "2. Copy your public key to the remote host:"
  echo "   ssh-copy-id $USER@$HOST"
  echo
  echo "3. Verify you can connect without a password:"
  echo "   ssh $USER@$HOST"
fi

#fin
