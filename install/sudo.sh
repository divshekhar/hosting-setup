#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"

install_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
        print_instruction "Installing sudo..."
        # Use su to install sudo
        su -c "apt-get update && apt-get install -y sudo"
        
        # Get current username
        current_user=$(whoami)
        
        # Add current user to sudo group
        su -c "usermod -aG sudo $current_user"
        
        print_instruction "sudo has been installed"
        
        # Ask user about terminal restart
        echo
        read -p "Would you like to restart your terminal now for sudo permissions to take effect? [Y/n] " restart_terminal
        restart_terminal=${restart_terminal:-Y}
        
        if [[ "$restart_terminal" =~ ^[Yy]$ ]]; then
            # Reload the user's group assignments without requiring a re-login
            exec su -l $current_user -c "cd '$PWD' && '$0' '$@'"
        fi
    else
        print_instruction "sudo is already installed"
    fi
}

# If script is run directly, execute installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_sudo
fi
