#!/bin/bash

# Source core modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/colors.sh"
source "$SCRIPT_DIR/core/system.sh"
source "$SCRIPT_DIR/core/utils.sh"
source "$SCRIPT_DIR/core/git.sh"

# Setup error handling
setup_error_handling

# Update system
update_system

# Setup repository
repo_path=$(setup_repository)

# Get deployment type
deployment_type=$(get_deployment_type "$repo_path")
required_version=$(get_required_version "$deployment_type" "$repo_path")

# Source deployment-specific install script
install_script="$SCRIPT_DIR/deployments/$deployment_type/install.sh"
if [ -f "$install_script" ]; then
    source "$install_script"
    if [[ $(type -t "install_$deployment_type") == function ]]; then
        "install_$deployment_type" "$repo_path" "$required_version"
    else
        print_error "Installation function not found for $deployment_type"
        exit 1
    fi
else
    print_error "Installation script not found for $deployment_type"
    exit 1
fi

# Setup environment file
setup_env_file "$repo_path"

# Handle submodules if present
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

# Final instructions
print_message "Setup completed successfully!"
echo
print_instruction "Next steps:"
print_instruction "1. cd into your repository: cd $repo_path"
print_instruction "2. Review your .env file if needed"
print_instruction "3. Run ./update.sh to build and start the project"
echo
print_instruction "Note: You may need to log out and log back in for some permission changes to take effect"
