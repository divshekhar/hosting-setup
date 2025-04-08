#!/bin/bash

# Source core modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/colors.sh"
source "$SCRIPT_DIR/core/system.sh"
source "$SCRIPT_DIR/core/utils.sh"

# List available versions (tags) in the repository
list_versions() {
    local repo_path=$1
    
    cd "$repo_path"
    print_message "Available versions"
    
    # Fetch all tags
    git fetch --tags
    
    # List tags in reverse chronological order
    local tags=$(git tag --sort=-creatordate)
    
    if [ -z "$tags" ]; then
        print_instruction "No version tags found. Using latest commit on main branch."
        echo "Latest commit: $(git rev-parse --short HEAD) - $(git log -1 --pretty=%B)"
    else
        echo "Available versions (latest first):"
        echo "$tags" | while read -r tag; do
            echo "  $tag - $(git log -1 --pretty=%B $tag)"
        done
    fi
}

# Update repository to specific version
update_repository() {
    local repo_path=$1
    local target_version=$2
    
    cd "$repo_path"
    
    if [ -z "$target_version" ]; then
        print_instruction "No specific version selected. Updating to latest..."
        git pull origin main
    else
        print_instruction "Checking out version: $target_version"
        git fetch --all --tags
        if git rev-parse "$target_version" >/dev/null 2>&1; then
            git checkout "$target_version"
        else
            print_error "Version $target_version not found"
            exit 1
        fi
    fi
}

# Setup error handling
setup_error_handling

# Validate and setup repository
setup_repository() {
    print_message "Repository Access"
    local is_private
    while true; do
        read -p "Is this a private repository? (Y/n) " is_private
        if [[ "$is_private" =~ ^[YyNn]$ ]]; then
            break
        else
            print_instruction "Please enter Y or n"
        fi
    done

    # Setup SSH if private repo
    if [[ "$is_private" =~ ^[Yy]$ ]]; then
        setup_ssh_key
        print_message "Testing GitHub connection"
        ssh -T git@github.com -o StrictHostKeyChecking=no || true
        read -p "Enter the GitHub repository SSH URL (git@github.com:username/repo.git): " repo_url
    else
        read -p "Enter the GitHub repository HTTPS URL (https://github.com/username/repo.git): " repo_url
    fi

    # Get clone directory
    print_message "Clone Directory Setup"
    local current_dir=$(pwd)
    print_instruction "Current directory: $current_dir"
    read -p "Where would you like to clone the repository? (Press Enter for current directory or provide path): " clone_dir

    # Handle empty input or expand ~
    clone_dir="${clone_dir:-$current_dir}"
    clone_dir="${clone_dir/#\~/$HOME}"

    # Create directory if needed
    if [ ! -d "$clone_dir" ]; then
        print_instruction "Creating directory: $clone_dir"
        mkdir -p "$clone_dir"
    fi

    # Change to specified directory
    cd "$clone_dir"
    print_instruction "Using directory: $(pwd)"

    # Handle existing repository
    local repo_name=$(basename "$repo_url" .git)
    if [ -d "$repo_name" ]; then
        print_instruction "Repository $repo_name already exists in $(pwd)/$repo_name"
        read -p "Do you want to remove it and clone again? (Y/n) " reclone
        if [[ "$reclone" =~ ^[Yy]$ ]]; then
            rm -rf "$repo_name"
            git clone "$repo_url"
        fi
    else
        git clone "$repo_url"
    fi

    echo "$(pwd)/$repo_name"
}

# Validate repository path
validate_repo() {
    local repo_path=$1
    
    if [ ! -d "$repo_path" ]; then
        print_error "Directory does not exist: $repo_path"
        return 1
    fi

    cd "$repo_path"
    if [ ! -d ".git" ]; then
        print_error "Not a git repository: $repo_path"
        return 1
    fi

    return 0
}

# Update system
update_system

# Show available versions and ask for specific version
list_versions "$repo_path"
read -p "Enter specific version to update to (press Enter for latest): " target_version

# Update repository
update_repository "$repo_path" "$target_version"

# Handle submodules
if detect_submodules "$repo_path"; then
    print_message "Submodule Management"
    echo "1. Update all submodules"
    echo "2. Update specific submodule"
    echo "3. Skip submodule updates"
    read -p "Choose an option (1-3): " sub_choice
    
    case $sub_choice in
        1)
            update_submodules "$repo_path"
            ;;
        2)
            git submodule status | sed 's/^-//' | awk '{print $2}'
            read -p "Enter submodule path: " submodule_path
            update_submodules "$repo_path" "$submodule_path"
            ;;
        3)
            print_instruction "Skipping submodule updates"
            ;;
        *)
            print_warning "Invalid choice, skipping submodule updates"
            ;;
    esac
fi

# Check/update environment file
setup_env_file "$repo_path"

# Get deployment type
deployment_type=$(get_deployment_type)

# Source deployment-specific deploy script
deploy_script="$SCRIPT_DIR/deployments/$deployment_type/deploy.sh"
if [ -f "$deploy_script" ]; then
    source "$deploy_script"
    if [[ $(type -t "deploy_$deployment_type") == function ]]; then
        "deploy_$deployment_type" "$repo_path"
    else
        print_error "Deployment function not found for $deployment_type"
        exit 1
    fi
else
    print_error "Deployment script not found for $deployment_type"
    exit 1
fi

print_message "Update completed successfully!"

# Setup SSH key for GitHub
setup_ssh_key() {
    print_message "Setting up SSH for GitHub"
    
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
        print_instruction "Existing SSH key found"
        print_message "Testing GitHub connection"
        ssh -T git@github.com -o StrictHostKeyChecking=no || true
    fi
}
