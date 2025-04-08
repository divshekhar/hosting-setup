#!/bin/bash

# Source core modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"
source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/utils.sh"

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