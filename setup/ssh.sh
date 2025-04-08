#!/bin/bash

# Source core modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/core/colors.sh"
source "$SCRIPT_DIR/core/system.sh"
source "$SCRIPT_DIR/core/utils.sh"

# Setup SSH key for GitHub
setup_github_ssh() {
    # First check if ssh-keygen is available
    if ! command -v ssh-keygen &> /dev/null; then
        print_error "ssh-keygen not found. Installing OpenSSH..."
        source "$SCRIPT_DIR/install/openssh.sh"
        install_openssh
    fi

    print_message "Setting up SSH for GitHub"
    
    # Get device name for comment
    default_device="Device"
    read -p "Enter your device name (default: $default_device): " device_name
    device_name=${device_name:-$default_device}
    
    # Get RSA key size
    default_bits=4096
    while true; do
        read -p "Enter RSA key size in bits (default: $default_bits): " key_bits
        key_bits=${key_bits:-$default_bits}
        if [[ "$key_bits" =~ ^[0-9]+$ ]] && [ "$key_bits" -ge 2048 ]; then
            break
        else
            print_error "Please enter a valid number (minimum 2048)"
        fi
    done
    
    # Get key filename
    default_keyname="github_id_rsa"
    read -p "Enter SSH key filename (default: $default_keyname): " key_filename
    key_filename=${key_filename:-$default_keyname}
    
    if [ ! -f ~/.ssh/${key_filename} ]; then
        print_instruction "No GitHub SSH key found. Creating new SSH key..."
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Generate the key with user preferences
        ssh-keygen -t rsa -b "$key_bits" \
                  -f ~/.ssh/${key_filename} \
                  -N "" \
                  -C "${device_name}@$(hostname)"
        
        # Add to SSH config
        if [ ! -f ~/.ssh/config ]; then
            touch ~/.ssh/config
            chmod 600 ~/.ssh/config
        fi
        
        if ! grep -q "Host github.com" ~/.ssh/config; then
            echo -e "\nHost github.com\n  IdentityFile ~/.ssh/${key_filename}\n  User git" >> ~/.ssh/config
        fi
        
        print_message "GitHub SSH Key Setup"
        echo "Here's your public SSH key:"
        echo "----------------------------------------------------------------"
        cat ~/.ssh/${key_filename}.pub
        echo "----------------------------------------------------------------"
        print_instruction "1. Copy the above public key"
        print_instruction "2. Go to GitHub -> Settings -> SSH and GPG keys -> New SSH key"
        print_instruction "3. Paste the key and save"

        while true; do
            read -p "Have you added the SSH key to GitHub? (Y/n) " response
            if [[ "$response" =~ ^[Yy]$ || -z "$response" ]]; then
                break
            else
                print_instruction "Please add the SSH key to GitHub before continuing"
            fi
        done

        # Test GitHub connection
        print_message "Testing GitHub connection"
        ssh -T git@github.com -o StrictHostKeyChecking=no || true
    else
        print_instruction "SSH key '${key_filename}' already exists"
        print_message "Testing GitHub connection"
        ssh -T git@github.com -o StrictHostKeyChecking=no || true
    fi
}
