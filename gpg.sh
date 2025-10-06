#!/bin/bash
set -e

# --- Configuration
DOCKER_IMAGE="gpg-cli:latest"

# We could put this in a container registry, but for now just build locally if needed
if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
  echo "Docker image '$DOCKER_IMAGE' not found, building..."
  docker build -t "$DOCKER_IMAGE" "$(dirname "$0")"
  echo "Image built successfully."
fi

# --- Argument Parsing
# This logic finds file paths and the --homedir argument to set up Docker mounts 
# to the local file-system

# Initialise arrays
declare -a docker_opts
declare -a gpg_args
declare -a seen_paths

# Use the host user's UID and GID to run the container,
# avoiding permission issues on mounted volumes
docker_opts+=("--user" "$(id -u):$(id -g)")

# Allocate a TTY if the script is run interactively
if [ -t 0 ] && [ -t 1 ]; then
    docker_opts+=("-it")
fi

# Allow Ctrl-C to be sent to gpg
docker_opts+=("--init")

# Default GPG home directory if --homedir is not specified
gpg_home_host="${GNUPGHOME:-$HOME/.gnupg}"
gpg_home_container="/home/gpguser/.gnupg"

# Track if user explicitly set --homedir or --passphrase
user_set_homedir=false
passphrase_provided=false

# Function to add a volume mount if the path hasn't been seen before
add_mount() {
    local host_path="$1"
    local container_path="$2"
    for seen in "${seen_paths[@]}"; do
        if [[ "$seen" == "$host_path" ]]; then
            return
        fi
    done
    docker_opts+=("-v" "${host_path}:${container_path}")
    seen_paths+=("$host_path")
}

# Function to handle a file path argument
handle_file_path() {
    local file_path="$1"
    # Get the absolute path of the file's directory
    local abs_dir
    abs_dir=$(cd "$(dirname -- "$file_path")" && pwd)
    add_mount "$abs_dir" "/work"
    gpg_args+=("/work/$(basename -- "$file_path")")
}

# Loop through all arguments to build Docker options and GPG command
while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
        # --- Home directory
        --homedir)
            user_set_homedir=true
            shift
            gpg_home_host="$1"
            # Handle the --homedir to gpg_args below not here
            ;;

        # --- Passphrase, force non-interactive mode
        --passphrase) # need to test |--passphrase-fd|--passphrase-file
            passphrase_provided=true
            if [[ "$arg" == "--passphrase" ]] || [[ "$#" -gt 1 && "$2" != -* ]]; then
                shift
                gpg_args+=("--pinentry-mode" "loopback" "$arg" "$1")
            fi
            ;;

        # --- File paths, for mounting
        # These are the only common arguments that are always followed by a file path
        -o|--output)
            gpg_args+=("$arg") # Pass the flag to gpg
            shift
            handle_file_path "$1"
            ;;

        # --- Standalone file path
        -*)
            # This is another gpg flag, just pass it through
            gpg_args+=("$arg")
            ;;
        *)
            # This is not a flag, assume it's a file path or argument
            if [ -e "$arg" ]; then
                handle_file_path "$arg"
            else
                # Not a file, just pass it through (e.g., a key ID)
                gpg_args+=("$arg")
            fi
            ;;
    esac
    shift
done

# Always add --homedir at the beginning, regardless if specified by user
gpg_args=("--homedir" "$gpg_home_container" "${gpg_args[@]}")

# --- Mount GPG home
mkdir -p "$gpg_home_host"
add_mount "$gpg_home_host" "$gpg_home_container"

# Add tmpfs mount for /run/user/UID to allow socket creation
docker_opts+=("--tmpfs" "/run/user/$(id -u):mode=700,uid=$(id -u),gid=$(id -g)")

# --- Execution
# Pass the container's GPG home path as an environment variable.
docker_opts+=("-e" "GPG_HOME_CONTAINER=${gpg_home_container}")

#echo "Running command in container: gpg ${gpg_args[*]}"
#echo docker run --rm "${docker_opts[@]}" "$DOCKER_IMAGE" "${gpg_args[@]}"
docker run --rm "${docker_opts[@]}" "$DOCKER_IMAGE" "${gpg_args[@]}"