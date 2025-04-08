#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/system.sh"

# Define dependencies for each tool
declare -A TOOL_DEPENDENCIES=(
    ["docker"]="sudo ca-certificates curl gnupg"
    ["git"]="sudo"
    ["node"]="sudo curl"
)

# Define installation functions for core dependencies
install_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
        print_message "Installing sudo..."
        apt-get update
        apt-get install -y sudo
        
        # Get current username
        current_user=$(whoami)
        
        # Add current user to sudo group
        usermod -aG sudo "$current_user"
        
        if ! command -v sudo >/dev/null 2>&1; then
            print_error "Failed to install sudo"
            return 1
        fi
    fi
    return 0
}

install_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        print_message "Installing curl..."
        if command -v sudo >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y curl
        else
            apt-get update
            apt-get install -y curl
        fi
    fi
    return 0
}

# Function to install a specific dependency
install_dependency() {
    local dep=$1
    
    case $dep in
        "sudo")
            if [ "$(id -u)" -ne 0 ]; then
                print_error "Root privileges required to install sudo. Please run with sudo or as root."
                return 1
            fi
            install_sudo
            ;;
        "curl")
            install_curl
            ;;
        *)
            if command -v sudo >/dev/null 2>&1; then
                sudo apt-get update
                sudo apt-get install -y "$dep"
            else
                if [ "$(id -u)" -ne 0 ]; then
                    print_error "Root privileges required to install $dep"
                    return 1
                fi
                apt-get update
                apt-get install -y "$dep"
            fi
            ;;
    esac
}

# Main function to ensure all dependencies for a tool
ensure_dependencies() {
    local tool=$1
    local deps="${TOOL_DEPENDENCIES[$tool]}"
    
    if [ -z "$deps" ]; then
        print_warning "No dependencies defined for $tool"
        return 0
    fi
    
    print_message "Checking dependencies for $tool..."
    
    # Install dependencies in order
    for dep in $deps; do
        print_instruction "Checking dependency: $dep"
        if ! install_dependency "$dep"; then
            print_error "Failed to install dependency: $dep"
            return 1
        fi
    done
    
    return 0
}
