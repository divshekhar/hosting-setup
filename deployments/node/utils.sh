#!/bin/bash

# Install specific Node.js version
install_nodejs_version() {
    local version=$1
    print_instruction "Installing Node.js ${version}.x..."
    
    # Remove existing Node.js installations
    sudo apt-get remove -y nodejs nodejs-doc libnode-dev libnode72 || true
    sudo apt-get autoremove -y
    sudo rm -rf /usr/local/bin/npm /usr/local/share/man/man1/node* /usr/local/lib/dtrace/node.d ~/.npm 2>/dev/null || true
    sudo rm -rf /usr/local/lib/node* /opt/local/bin/node /opt/local/include/node /opt/local/lib/node* 2>/dev/null || true
    sudo rm -rf /usr/local/include/node* /usr/local/bin/node* 2>/dev/null || true

    # Clean apt cache
    sudo rm -rf /var/lib/apt/lists/*
    sudo apt-get clean
    sudo apt-get update

    # Install Node.js
    curl -fsSL "https://deb.nodesource.com/setup_${version}.x" | sudo -E bash -
    sudo apt-get install -y nodejs --fix-broken
}

# Check and update Node.js version
check_nodejs_version() {
    local required_version=$1
    
    if command_exists node; then
        local current_version=$(node -v | cut -d. -f1 | tr -d 'v')
        if [ "$current_version" -eq "$required_version" ]; then
            print_instruction "Node.js ${required_version}.x is already installed ($(node --version))"
            return 0
        fi
    fi
    
    install_nodejs_version "$required_version"
}