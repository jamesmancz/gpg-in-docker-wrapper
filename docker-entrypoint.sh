#!/bin/sh
# Docker entrypoint script to set up environment and run gpg
set -e

# Get GPG home directory from environment variable
export GNUPGHOME="${GPG_HOME_CONTAINER}"
# TTY for gpg-agent to use
export GPG_TTY=$(tty 2>/dev/null || echo /dev/null)
# Create XDG_RUNTIME_DIR for gpg-agent sockets
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p -m 700 "$XDG_RUNTIME_DIR"

# Start gpg-agent
eval $(gpg-agent --daemon --no-grab 2>/dev/null)

# Debug: Show ALL files in GNUPGHOME
#echo "Debug: All files in GNUPGHOME:"
#ls -la "$GNUPGHOME"

# Execute gpg with all arguments
#echo "Executing gpg with args: $@"
exec gpg "$@"