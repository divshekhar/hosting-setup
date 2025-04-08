#!/bin/bash

# Source core modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/colors.sh"
source "$SCRIPT_DIR/core/system.sh"
source "$SCRIPT_DIR/core/utils.sh"

# Setup error handling
setup_error_handling

# Get repository path
read -p "Enter the path to your repository (default: current directory): " repo_path
repo_path=${repo_path:-$(pwd)}

# Validate repository
validate_repo "$repo_path" || exit 1

# Update system and pull changes
update_system
cd "$repo_path"
git pull origin main

# Update submodules
update_submodules "$repo_path"

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