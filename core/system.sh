#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
package_installed() {
    dpkg -l "$1" | grep -q '^ii'
}

# Update system packages if needed
update_system() {
    print_message "Checking system packages"
    if [ -z "$(find /var/lib/apt/lists -maxdepth 1 -mtime -1)" ]; then
        print_instruction "System packages need updating..."
        # If we're root, don't use sudo
        if [ "$(id -u)" -eq 0 ]; then
            apt-get update
            apt-get upgrade -y
        else
            sudo apt-get update
            sudo apt-get upgrade -y
        fi
    else
        print_instruction "System packages are up to date"
    fi
}

# Setup error handling
setup_error_handling() {
    set -e
    trap 'echo "Error occurred in script at line: $LINENO"' ERR
}

# Run a command with or without sudo based on current user
run_with_privileges() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}
