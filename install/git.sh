#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/dependencies.sh"

function install_git {
    # First ensure all dependencies are met
    if ! ensure_dependencies "git"; then
        print_error "Failed to install dependencies for Git"
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        print_instruction "Installing Git..."
        sudo apt-get update
        sudo apt-get install -y git
        print_instruction "Git has been installed ($(git --version))"
    else
        print_instruction "Git is already installed ($(git --version))"
    fi
}

# If script is run directly, execute installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_git
fi
