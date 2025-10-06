# GPG Container Wrapper

This project provides a Dockerfile for a containerised `gpg` along with a seamless wrapper script that allows you to run `gpg` commands inside the container, while making it feel like you're running `gpg` natively on your host machine.

It intelligently handles file paths (mounting them into the container runtime), along with batch and interactive sessions, making it a portable and secure way to manage GPG operations across different environments.

## Table of Contents

- Purpose: Why Run GPG in a Container?
- How It Works
- Installation and Usage
- Usage Examples

## Purpose: Why Run GPG in a Container?

Encapsulating GPG within a container offers several key advantages:

*   **Portability & Consistency**: Guarantees that you are using the exact same version of GPG with the same configuration, regardless of the host operating system (macOS, Windows, different Linux distros). This eliminates "works on my machine" problems, especially in CI/CD pipelines.
*   **Dependency Isolation**: Avoids the need to install GPG and its various dependencies & libraries directly on your host system. This keeps your host machine clean and avoids potential conflicts with other installed software.
*   **Enhanced Security**: The container runs as a non-root user. The wrapper script is designed to only grant the container access to the specific directories it needs: your GPG home directory (`~/.gnupg`) and the working directory of any files you're processing. This sandboxing limits the container's access to your host filesystem.
*   **Simplified Automation**: Provides a stable and predictable environment for scripts and automated processes that rely on GPG, ensuring they behave consistently everywhere.

## How It Works

The project consists of three main components that work together:

1.  **`gpg.sh` (The Wrapper Script)**
    This is the user-facing script that you interact with. It acts as a smart proxy for the `gpg` binary in the container.
    -   It parses your command-line arguments to find file paths and the `--homedir` location.
    -   It automatically builds the Docker image (`gpg-cli:latest`) on its first run if it doesn't already exist.
    -   It maps the host user's UID/GID into the container, ensuring that any files created have the correct ownership and avoiding permission errors.
    -   It detects if it's being run in an interactive terminal and adds the `-it` flags to the `docker run` command, allowing for interactive prompts like passphrase entry.
    -   It dynamically creates Docker volume mounts (`-v`) for your GPG home and any files you're working with.
    -   Finally, it executes `docker run` with all the carefully constructed arguments, passing your original command to the container.

2.  **`Dockerfile`**
    This file defines the container image.
    -   It starts from a minimal `alpine:latest` base image to keep the size small.
    -   It installs `gnupg` and its necessary dependencies for interactive use.
    -   It creates a dedicated, non-root `gpguser` for running the commands, following security best practices.
    -   It sets the `ENTRYPOINT` to the `docker-entrypoint.sh` script.

3.  **`docker-entrypoint.sh`**
    This script is the first thing that runs inside the container.
    -   It sets up the necessary environment variables for GPG.
    -   It starts the `gpg-agent` daemon, which is crucial for caching passphrases and managing keys.
    -   It uses `exec gpg "$@"` to replace itself with the `gpg` command, passing along all the arguments it received from the wrapper.

## Installation and Usage

### Prerequisites

You must have Docker installed and running on your system.

### Installation

The easiest way to use the wrapper is to make it executable and place it in your system's `PATH`. For a completely seamless experience, you can use the `gpg` symlink to the `gpg.sh` script.

1.  **Make the script executable:**
    ```shell
    chmod +x /path/to/gpg-container-wrapper/gpg.sh
    ```

2.  **Create a symbolic link in your PATH:**
    This makes it so you can just type `gpg` from anywhere in your terminal.
    ```shell
    # Example for Linux or macOS
    sudo ln -s /path/to/gpg-container-wrapper/gpg.sh /usr/local/bin/gpg
    ```

Now, whenever you run the `gpg` command, you'll be using the containerised version. The first run will take a moment to build the Docker image. Subsequent runs will be much faster.

## Usage Examples

Because this is a transparent wrapper, you use the exact same `gpg` commands you would use natively. The script handles the file path translations for you.

**Note:** The examples assume you have completed the installation step to link `gpg.sh` to `gpg`. If not, replace `gpg` with `./gpg.sh`.

---

#### Generate a new key pair
The wrapper will automatically use interactive mode to prompt you for details and a passphrase.
```shell
gpg --full-generate-key
```

---

#### List your public keys
```shell
gpg --list-keys
```

---

#### Encrypt a file
The wrapper will automatically mount the directory containing `mydocument.txt` into the container.
```shell
gpg --encrypt --recipient "user@example.com" mydocument.txt
```
*(This will create `mydocument.txt.gpg` in the same directory.)*

---

#### Decrypt a file
You will be prompted for your passphrase to unlock the private key.
```shell
gpg --decrypt mydocument.txt.gpg > mydocument.txt
```

---

#### Use a custom GPG home directory
The wrapper correctly handles the `--homedir` argument, mounting your custom directory into the container.
```shell
gpg --homedir /path/to/my/other-gpg-home --list-keys
```