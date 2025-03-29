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

# 1. Update the machine
print_message "Updating system packages"
sudo apt-get update
sudo apt-get upgrade -y

# 2. Install required dependencies
print_message "Installing required dependencies"

# Install Git
sudo apt-get install -y git

# Install Docker
print_message "Installing Docker"
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

# Add current user to docker group
sudo usermod -aG docker $USER
print_instruction "Please note: Docker permission changes will take effect after you log out and back in"

# Install Node.js and npm
print_message "Installing Node.js and npm"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installations
print_message "Verifying installations"
git --version
docker --version
node --version
npm --version

# Ask if repository is private
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
    # Setup for private repository
    print_message "Setting up GitHub SSH key"
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi

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

    print_message "Testing GitHub connection"
    ssh -T git@github.com -o StrictHostKeyChecking=no || true

    print_message "Repository setup"
    read -p "Enter the GitHub repository SSH URL (git@github.com:username/repo.git): " repo_url
else
    # Setup for public repository
    print_message "Repository setup"
    read -p "Enter the GitHub repository HTTPS URL (https://github.com/username/repo.git): " repo_url
fi

# Clone the repository
print_message "Cloning repository"
git clone "$repo_url"

# Get the repository name from the URL (works for both HTTPS and SSH URLs)
repo_name=$(basename "$repo_url" .git)

# Final instructions
print_message "Setup completed successfully!"
echo
print_instruction "Next steps:"
print_instruction "1. cd into your repository: cd $repo_name"
print_instruction "2. Create/edit your .env file"
print_instruction "3. Run ./update.sh to build and start the project"
echo
print_instruction "Note: You may need to log out and log back in for Docker permissions to take effect"
