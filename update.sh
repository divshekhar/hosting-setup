#!/bin/bash

# Print colored output
print_message() {
    GREEN='\033[0;32m'
    NC='\033[0m' # No Color
    echo -e "${GREEN}=== $1 ===${NC}"
}

print_warning() {
    YELLOW='\033[1;33m'
    NC='\033[0m'
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Error handling
set -e  # Exit on any error
error_handler() {
    echo "Error occurred in script at line: $1"
    exit 1
}
trap 'error_handler ${LINENO}' ERR

# Ask for repository directory
print_message "Repository Setup"
read -p "Enter the path to your repository (default: current directory): " repo_path
repo_path=${repo_path:-$(pwd)}

# Validate and change to the repository directory
if [ ! -d "$repo_path" ]; then
    print_warning "Directory does not exist: $repo_path"
    exit 1
fi

cd "$repo_path"
print_message "Working in: $(pwd)"

# Check if it's a git repository
if [ ! -d ".git" ]; then
    print_warning "Not a git repository: $repo_path"
    exit 1
fi

# 1. Update the machine
print_message "Updating system packages"
sudo apt-get update
sudo apt-get upgrade -y

# 2. Git pull in the directory
print_message "Pulling latest changes"
git pull origin main

# 3. Check and update submodules
if [ -f ".gitmodules" ]; then
    print_message "Updating submodules"
    git submodule update --init --recursive
    git submodule update --remote --merge
fi

# 4. Check .env file
print_message "Checking environment file"
if [ ! -f ".env" ]; then
    read -p "No .env file found. Would you like to create one? (Y/n): " create_env
    if [[ "$create_env" =~ ^[Yy]$ ]]; then
        print_message "Please paste your .env content (press Ctrl+D when done):"
        cat > .env
    else
        print_warning "Proceeding without .env file"
    fi
elif [ ! -s ".env" ]; then
    print_warning ".env file is empty"
    read -p "Do you want to proceed with empty .env? (Y/n): " proceed_empty
    if [[ ! "$proceed_empty" =~ ^[Yy]$ ]]; then
        print_message "Please paste your .env content (press Ctrl+D when done):"
        cat > .env
    fi
fi

# 5 & 6. Detect Dockerfiles and handle build
print_message "Checking for Dockerfile"
dockerfiles=($(find . -maxdepth 1 -type f -name "Dockerfile*"))

if [ ${#dockerfiles[@]} -eq 0 ]; then
    print_warning "No Dockerfile found. Exiting..."
    exit 1
fi

# Ask user about build preference
read -p "Do you want to use Docker build? (Y/n): " use_docker
if [[ ! "$use_docker" =~ ^[Yy]$ ]]; then
    print_message "Skipping Docker build. Please provide your build command:"
    read -p "> " custom_command
    eval "$custom_command"
    exit 0
fi

# Handle multiple Dockerfiles
selected_dockerfile="Dockerfile"
if [ ${#dockerfiles[@]} -gt 1 ]; then
    echo "Multiple Dockerfiles found:"
    for i in "${!dockerfiles[@]}"; do
        echo "$((i+1)). ${dockerfiles[$i]}"
    done
    read -p "Select Dockerfile (1-${#dockerfiles[@]}, default is Dockerfile): " dockerfile_choice
    if [[ -n "$dockerfile_choice" && "$dockerfile_choice" -le "${#dockerfiles[@]}" ]]; then
        selected_dockerfile="${dockerfiles[$((dockerfile_choice-1))]}"
    fi
fi

# 7. Parse Dockerfile and build command
print_message "Analyzing $selected_dockerfile"
# Extract exposed ports from Dockerfile
exposed_ports=($(grep -i "^EXPOSE" "$selected_dockerfile" | awk '{for(i=2;i<=NF;i++) print $i}'))
default_port=${exposed_ports[0]:-3000}

# Get project name from directory
project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')

# Ask for build details
read -p "Enter image name (default: $project_name): " image_name
image_name=${image_name:-$project_name}

read -p "Enter host port (default: $default_port): " host_port
host_port=${host_port:-$default_port}

# 9 & 10. Check for running containers on the same port
existing_container=$(sudo docker ps -q -f "publish=$host_port")
if [ -n "$existing_container" ]; then
    print_warning "Container already running on port $host_port"
    sudo docker ps -f "publish=$host_port"
    read -p "Would you like to stop this container? (Y/n): " stop_container
    if [[ "$stop_container" =~ ^[Yy]$ ]]; then
        sudo docker stop "$existing_container"
        sudo docker rm "$existing_container"
    else
        print_warning "Cannot proceed with port $host_port in use"
        exit 1
    fi
fi

# 8. Allow custom docker command
read -p "Use default docker build command? (Y/n): " use_default
if [[ "$use_default" =~ ^[Yy]$ ]]; then
    # Build the image
    print_message "Building Docker image"
    sudo docker build -f "$selected_dockerfile" -t "$image_name" .

    # 11. Run the container
    print_message "Starting Docker container"
    sudo docker run -d \
        --name "$image_name" \
        --restart unless-stopped \
        -p "$host_port:$default_port" \
        --env-file .env \
        "$image_name"
else
    print_message "Enter your custom docker build command:"
    read -p "> " custom_docker_command
    eval "sudo $custom_docker_command"
fi

# Verify the container is running
print_message "Verifying container status"
sudo docker ps | grep "$image_name"

print_message "Container logs:"
sudo docker logs "$image_name"

print_message "Update completed successfully!"
