#!/bin/bash

# Source colors for consistent output
source "$(dirname "${BASH_SOURCE[0]}")/core/colors.sh"

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        print_instruction "You can install Docker by running: ./deploid.sh and selecting 'Install' > 'Docker'"
        exit 1
    fi
}

# Function to build Docker image
build_image() {
    print_message "Building Docker image 'deploid'..."
    if ! docker build -t deploid .; then
        print_error "Failed to build Docker image"
        exit 1
    fi
    print_message "Docker image built successfully!"
}

# Function to cleanup existing containers
cleanup_containers() {
    local running_containers=$(docker ps -q --filter ancestor=deploid)
    local stopped_containers=$(docker ps -aq --filter ancestor=deploid --filter status=exited)
    
    if [ -n "$running_containers" ]; then
        print_message "Stopping running containers..."
        docker stop $running_containers
    fi
    
    if [ -n "$stopped_containers" ]; then
        print_message "Removing stopped containers..."
        docker rm $stopped_containers
    fi
}

# Function to run container
run_container() {
    print_message "Starting Docker container..."
    print_instruction "Container will start in interactive mode"
    print_instruction "Initial command: ./deploid.sh"
    print_instruction "Use 'exit' to leave the container"
    echo
    docker run -it --privileged deploid /bin/bash -c "./deploid.sh; bash"
}

# Main execution
main() {
    print_message "=== Deploid Test Environment ==="
    echo
    
    # Check Docker installation
    check_docker
    
    # Always build a fresh image
    build_image
    
    # Clean up existing containers
    cleanup_containers
    
    # Run container
    run_container
}

# Execute main function
main
