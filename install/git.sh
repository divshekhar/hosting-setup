#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"

install_git() {
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