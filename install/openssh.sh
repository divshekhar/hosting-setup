#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/system.sh"

install_openssh() {
    # Check if sudo is available, if not, install it first
    if ! command -v sudo >/dev/null 2>&1; then
        print_instruction "sudo not found. Installing sudo first..."
        # Use su to install sudo
        su -c "apt-get update && apt-get install -y sudo"
        
        # Get current username
        current_user=$(whoami)
        
        # Add current user to sudo group
        su -c "usermod -aG sudo $current_user"
    fi

    # Check if OpenSSH is already installed
    if command -v ssh >/dev/null 2>&1; then
        print_instruction "OpenSSH is already installed ($(ssh -V 2>&1))"
        return 0
    fi

    print_instruction "Installing OpenSSH..."
    
    # If we're root, don't use sudo
    if [ "$(id -u)" -eq 0 ]; then
        apt-get update
        apt-get install -y openssh-client openssh-server
    else
        sudo apt-get update
        sudo apt-get install -y openssh-client openssh-server
    fi

    # Start and enable SSH service
    if ! systemctl is-active --quiet ssh; then
        print_instruction "Starting SSH service..."
        if [ "$(id -u)" -eq 0 ]; then
            systemctl start ssh
            systemctl enable ssh
        else
            sudo systemctl start ssh
            sudo systemctl enable ssh
        fi
    fi

    # Configure SSH service
    if [ ! -f /etc/ssh/sshd_config ]; then
        print_error "SSH configuration file not found"
        return 1
    fi

    # Secure SSH configuration
    print_instruction "Configuring SSH security settings..."
    
    # Backup original config
    if [ "$(id -u)" -eq 0 ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        
        # Set secure defaults
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        
        # Restart SSH service to apply changes
        systemctl restart ssh
    else
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        
        # Set secure defaults
        sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        
        # Restart SSH service to apply changes
        sudo systemctl restart ssh
    fi

    print_instruction "OpenSSH installation completed!"
    return 0
}

# If script is run directly, execute installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_openssh
fi
