#\!/usr/bin/env bash
set -euo pipefail

# Simple SSH connectivity test for the remote backup feature

# Target host (uses okusi0 as specified in requirements)
HOST="okusi0"
if [[ -n "${1:-}" ]]; then
  HOST="$1"
fi

USER="${USER:-$(whoami)}"
if [[ -n "${2:-}" ]]; then
  USER="$2"
fi

echo "Testing SSH connectivity to $USER@$HOST..."

# Try SSH with batch mode and connection timeout
if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$USER@$HOST" "echo 'Connection successful'" 2>/dev/null; then
  echo "✓ Connection successful\!"
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
