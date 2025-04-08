#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/system.sh"

# Define dependencies for each tool
declare -A TOOL_DEPENDENCIES=(
    ["docker"]="ca-certificates curl gnupg"
    ["git"]=""
    ["node"]="curl"
)

# Function to install a specific dependency
install_dependency() {
    local dep=$1
    
    # If we're root, don't use sudo
    if [ "$(id -u)" -eq 0 ]; then
        apt-get update
        apt-get install -y "$dep"
    else
        sudo apt-get update
        sudo apt-get install -y "$dep"
    fi
}

# Main function to ensure all dependencies for a tool
ensure_dependencies() {
    local tool=$1
    local deps="${TOOL_DEPENDENCIES[$tool]}"
    
    if [ -z "$deps" ]; then
        print_instruction "No dependencies required for $tool"
        return 0
    fi
    
    print_message "Checking dependencies for $tool..."
    
    # Install dependencies in order
    for dep in $deps; do
        print_instruction "Checking dependency: $dep"
        if ! command_exists "$dep"; then
            if ! install_dependency "$dep"; then
                print_error "Failed to install dependency: $dep"
                return 1
            fi
        fi
    done
    
    return 0
}
