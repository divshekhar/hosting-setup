#!/bin/bash

# Print colored output
print_message() {
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
    echo -e "${GREEN}=== $1 ===${NC}"
}

print_instruction() {
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
    echo -e "${BLUE}>>> $1${NC}"
}

# Error handling
set -e  # Exit on any error
error_handler() {
    echo "Error occurred in script at line: $1"
    exit 1
}
trap 'error_handler ${LINENO}' ERR

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
package_installed() {
    dpkg -l "$1" | grep -q '^ii'
}

# 1. Update the machine
print_message "Checking system packages"
if [ -z "$(find /var/lib/apt/lists -maxdepth 1 -mtime -1)" ]; then
    print_instruction "System packages need updating..."
    sudo apt-get update
    sudo apt-get upgrade -y
else
    print_instruction "System packages are up to date"
fi

# 2. Install required dependencies
print_message "Checking required dependencies"

# Check and install Git
if ! command_exists git; then
    print_instruction "Installing Git..."
    sudo apt-get install -y git
else
    print_instruction "Git is already installed ($(git --version))"
fi

# Check and install Docker
if ! command_exists docker; then
    print_message "Installing Docker..."
    if ! package_installed docker-ce; then
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

    # Check if user is in docker group
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        print_instruction "Adding user to docker group..."
        sudo usermod -aG docker "$USER"
        print_instruction "Please note: Docker permission changes will take effect after you log out and back in"
    fi
else
    print_instruction "Docker is already installed ($(docker --version))"
    if groups "$USER" | grep -q '\bdocker\b'; then
        print_instruction "User is already in docker group"
    else
        print_instruction "Adding user to docker group..."
        sudo usermod -aG docker "$USER"
        print_instruction "Please note: Docker permission changes will take effect after you log out and back in"
    fi
fi

# Check and install Node.js and npm
print_message "Checking Node.js installation"
REQUIRED_NODE_VERSION="22"

install_nodejs() {
    print_instruction "Installing Node.js ${REQUIRED_NODE_VERSION}.x..."
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
    curl -fsSL https://deb.nodesource.com/setup_${REQUIRED_NODE_VERSION}.x | sudo -E bash -
    sudo apt-get install -y nodejs --fix-broken
}

if command_exists node; then
    CURRENT_NODE_VERSION=$(node -v | cut -d. -f1 | tr -d 'v')
    if [ "$CURRENT_NODE_VERSION" -eq "$REQUIRED_NODE_VERSION" ]; then
        print_instruction "Node.js ${REQUIRED_NODE_VERSION}.x is already installed ($(node --version))"
    else
        print_instruction "Updating Node.js to version ${REQUIRED_NODE_VERSION}.x..."
        install_nodejs
    fi
else
    install_nodejs
fi

# Verify installations
print_message "Verifying installations"
git --version
docker --version
node --version
npm --version

# Check for existing SSH key
print_message "Repository Access"
while true; do
    read -p "Is this a private repository? (Y/n) " is_private
    if [[ "$is_private" =~ ^[YyNn]$ ]]; then
        break
    else
        print_instruction "Please enter Y or n"
    fi
done

if [[ "$is_private" =~ ^[Yy]$ ]]; then
    print_message "Checking SSH configuration"
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_instruction "No SSH key found. Creating new SSH key..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        print_message "GitHub SSH Key Setup"
        echo "Here's your public SSH key:"
        echo "----------------------------------------------------------------"
        cat ~/.ssh/id_rsa.pub
        echo "----------------------------------------------------------------"
        print_instruction "1. Copy the above public key"
        print_instruction "2. Go to GitHub -> Settings -> SSH and GPG keys -> New SSH key"
        print_instruction "3. Paste the key and save"

        while true; do
            read -p "Have you added the SSH key to GitHub? (Y/n) " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                break
            else
                print_instruction "Please add the SSH key to GitHub before continuing"
            fi
        done
    else
        print_instruction "Existing SSH key found"
    fi

    print_message "Testing GitHub connection"
    ssh -T git@github.com -o StrictHostKeyChecking=no || true

    print_message "Repository setup"
    read -p "Enter the GitHub repository SSH URL (git@github.com:username/repo.git): " repo_url
else
    print_message "Repository setup"
    read -p "Enter the GitHub repository HTTPS URL (https://github.com/username/repo.git): " repo_url
fi

# Get clone directory
print_message "Clone Directory Setup"
current_dir=$(pwd)
print_instruction "Current directory: $current_dir"
read -p "Where would you like to clone the repository? (Press Enter for current directory or provide path): " clone_dir

# Handle empty input (use current directory) or expand ~ if present
clone_dir="${clone_dir:-$current_dir}"
clone_dir="${clone_dir/#\~/$HOME}"

# Create directory if it doesn't exist
if [ ! -d "$clone_dir" ]; then
    print_instruction "Creating directory: $clone_dir"
    mkdir -p "$clone_dir"
fi

# Change to the specified directory
cd "$clone_dir"
print_instruction "Using directory: $(pwd)"

# Check if repository already exists
repo_name=$(basename "$repo_url" .git)
if [ -d "$repo_name" ]; then
    print_instruction "Repository $repo_name already exists in $(pwd)/$repo_name"
    read -p "Do you want to remove it and clone again? (Y/n) " reclone
    if [[ "$reclone" =~ ^[Yy]$ ]]; then
        rm -rf "$repo_name"
        print_message "Cloning repository"
        git clone "$repo_url"
    fi
else
    print_message "Cloning repository"
    git clone "$repo_url"
fi

# Final instructions
print_message "Setup completed successfully!"
echo
print_instruction "Next steps:"
print_instruction "1. cd into your repository: cd $(pwd)/$repo_name"
print_instruction "2. Create/edit your .env file"
print_instruction "3. Run ./update.sh to build and start the project"
echo
print_instruction "Note: You may need to log out and log back in for Docker permissions to take effect"
