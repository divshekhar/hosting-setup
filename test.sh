#!/bin/bash

# Source colors for consistent output
source "$(dirname "${BASH_SOURCE[0]}")/core/colors.sh"

# Container name constant
CONTAINER_NAME="deploid-test"

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
    print_message "Cleaning up existing containers..."
    
    # Find containers by name (both running and stopped)
    local containers=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.ID}}")
    
    if [ -n "$containers" ]; then
        # Stop running containers
        print_instruction "Stopping containers..."
        echo "$containers" | xargs docker stop
        
        # Remove containers
        print_instruction "Removing containers..."
        echo "$containers" | xargs docker rm -f
        
        print_message "Cleanup completed!"
    else
        print_instruction "No existing containers found"
    fi

    # Additional cleanup for any containers using the deploid image
    local image_containers=$(docker ps -a --filter "ancestor=deploid" --format "{{.ID}}")
    
    if [ -n "$image_containers" ]; then
        print_instruction "Cleaning up additional containers using deploid image..."
        echo "$image_containers" | xargs docker stop
        echo "$image_containers" | xargs docker rm -f
    fi
}

# Function to run container
run_container() {
    print_message "Starting Docker container..."
    print_instruction "Container will start in interactive mode"
    print_instruction "Initial command: ./deploid.sh"
    print_instruction "Use 'exit' to leave the container"
    echo
    docker run -it --privileged --name "$CONTAINER_NAME" deploid /bin/bash -c "./deploid.sh; bash"
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
