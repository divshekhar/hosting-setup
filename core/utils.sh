#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Validate repository directory
validate_repo() {
    local repo_path=$1
    
    if [ ! -d "$repo_path" ]; then
        print_error "Directory does not exist: $repo_path"
        return 1
    fi

    if [ ! -d "$repo_path/.git" ]; then
        print_error "Not a git repository: $repo_path"
        return 1
    fi

    return 0
}

# Detect deployment type based on repository content
get_deployment_type() {
    local repo_path=${1:-$(pwd)}
    
    # Check for Docker deployment
    if [ -f "$repo_path/Dockerfile" ] || [ -n "$(find "$repo_path" -maxdepth 1 -type f -name 'Dockerfile*')" ]; then
        echo "docker"
        return
    fi
    
    # Check for Node.js deployment
    if [ -f "$repo_path/package.json" ]; then
        echo "node"
        return
    fi
    
    # Check for Python deployment
    if [ -f "$repo_path/requirements.txt" ] || [ -f "$repo_path/setup.py" ]; then
        echo "python"
        return
    fi
    
    # Default to basic deployment
    echo "basic"
}

# Get required version for specific deployment type
get_required_version() {
    local deployment_type=$1
    local repo_path=${2:-$(pwd)}
    
    case $deployment_type in
        "node")
            if [ -f "$repo_path/package.json" ]; then
                local node_version=$(grep '"node":' "$repo_path/package.json" | grep -o '[0-9]\+' | head -1)
                echo "${node_version:-22}"  # Default to 22 if not specified
                return
            fi
            ;;
        "python")
            if [ -f "$repo_path/runtime.txt" ]; then
                local python_version=$(cat "$repo_path/runtime.txt" | grep -o '[0-9]\.[0-9]\+')
                echo "${python_version:-3.11}"  # Default to 3.11 if not specified
                return
            fi
            ;;
    esac
    
    # Return default version if not found
    echo "latest"
}

# Handle repository setup
setup_repository() {
    print_message "Repository Access"
    local repo_url=""
    
    # Check if private repository
    while true; do
        read -p "Is this a private repository? (Y/n) " is_private
        if [[ "$is_private" =~ ^[YyNn]$ ]]; then
            break
        else
            print_instruction "Please enter Y or n"
        fi
    done

    if [[ "$is_private" =~ ^[Yy]$ ]]; then
        setup_ssh_key
        read -p "Enter the GitHub repository SSH URL (git@github.com:username/repo.git): " repo_url
    else
        read -p "Enter the GitHub repository HTTPS URL (https://github.com/username/repo.git): " repo_url
    fi

    clone_repository "$repo_url"
}

# Setup SSH key
setup_ssh_key() {
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
}

# Clone repository
clone_repository() {
    local repo_url=$1
    
    print_message "Clone Directory Setup"
    current_dir=$(pwd)
    print_instruction "Current directory: $current_dir"
    read -p "Where would you like to clone the repository? (Press Enter for current directory or provide path): " clone_dir

    clone_dir="${clone_dir:-$current_dir}"
    clone_dir="${clone_dir/#\~/$HOME}"

    if [ ! -d "$clone_dir" ]; then
        print_instruction "Creating directory: $clone_dir"
        mkdir -p "$clone_dir"
    fi

    cd "$clone_dir"
    print_instruction "Using directory: $(pwd)"

    repo_name=$(basename "$repo_url" .git)
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

    echo "$clone_dir/$repo_name"
}

# Setup environment file
setup_env_file() {
    local repo_path=$1
    
    print_message "Checking environment file"
    if [ ! -f "$repo_path/.env" ]; then
        read -p "No .env file found. Would you like to create one? (Y/n): " create_env
        if [[ "$create_env" =~ ^[Yy]$ ]]; then
            print_message "Please paste your .env content (press Ctrl+D when done):"
            cat > "$repo_path/.env"
        else
            print_warning "Proceeding without .env file"
        fi
    elif [ ! -s "$repo_path/.env" ]; then
        print_warning ".env file is empty"
        read -p "Do you want to proceed with empty .env? (Y/n): " proceed_empty
        if [[ ! "$proceed_empty" =~ ^[Yy]$ ]]; then
            print_message "Please paste your .env content (press Ctrl+D when done):"
            cat > "$repo_path/.env"
        fi
    fi
}

# Detect if repository has submodules
detect_submodules() {
    local repo_path=$1
    [ -f "$repo_path/.gitmodules" ]
}

# Update git submodules with enhanced error handling
update_submodules() {
    local repo_path=$1
    local specific_module=$2
    
    if [ -f "$repo_path/.gitmodules" ]; then
        print_message "Updating submodules"
        
        # Initialize submodules if not already initialized
        git submodule init || {
            print_warning "Failed to initialize submodules"
            return 1
        }
        
        # Fetch updates for all submodules
        git fetch --recurse-submodules || {
            print_warning "Failed to fetch submodule updates"
            return 1
        }
        
        if [ -n "$specific_module" ]; then
            # Update specific submodule
            cd "$repo_path/$specific_module"
            git checkout master || true
            git pull origin master || {
                print_warning "Failed to update specific submodule: $specific_module"
                return 1
            }
            cd "$repo_path"
        else
            # Update all submodules
            git submodule update --init --recursive --force || {
                print_warning "Some submodules might be out of sync, attempting alternative update"
                git submodule foreach git checkout master || true
                git submodule foreach git pull origin master || true
            }
        fi
        
        print_message "Submodule update completed"
    fi
}
