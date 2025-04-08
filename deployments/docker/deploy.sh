#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/colors.sh"

# Deploy Docker application
deploy_docker() {
    local repo_path=$1
    
    # Validate Docker installation
    if ! command_exists docker; then
        print_error "Docker is not installed"
        return 1
    fi

    # Setup Docker deployment
    setup_docker_deployment "$repo_path"
}
