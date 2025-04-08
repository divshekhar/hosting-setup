#!/bin/bash

# Find and select Dockerfile
select_dockerfile() {
    local repo_path=$1
    local dockerfiles=($(find "$repo_path" -maxdepth 1 -type f -name "Dockerfile*"))
    local selected_dockerfile="Dockerfile"

    if [ ${#dockerfiles[@]} -eq 0 ]; then
        print_error "No Dockerfile found"
        return 1
    elif [ ${#dockerfiles[@]} -gt 1 ]; then
        echo "Multiple Dockerfiles found:"
        for i in "${!dockerfiles[@]}"; do
            echo "$((i+1)). ${dockerfiles[$i]}"
        done
        read -p "Select Dockerfile (1-${#dockerfiles[@]}, default is Dockerfile): " dockerfile_choice
        if [[ -n "$dockerfile_choice" && "$dockerfile_choice" -le "${#dockerfiles[@]}" ]]; then
            selected_dockerfile="${dockerfiles[$((dockerfile_choice-1))]}"
        fi
    fi
    
    echo "$selected_dockerfile"
}

# Analyze Dockerfile and get exposed ports
get_exposed_ports() {
    local dockerfile=$1
    grep -i "^EXPOSE" "$dockerfile" | awk '{for(i=2;i<=NF;i++) print $i}'
}

# Check for running containers on specific port
check_port_conflict() {
    local port=$1
    sudo docker ps -q -f "publish=$port"
}

# Handle container management
manage_container() {
    local image_name=$1
    local host_port=$2
    local default_port=$3
    local dockerfile=$4

    # Check for existing containers
    local existing_container=$(check_port_conflict "$host_port")
    if [ -n "$existing_container" ]; then
        print_warning "Container already running on port $host_port"
        sudo docker ps -f "publish=$host_port"
        read -p "Would you like to stop this container? (Y/n): " stop_container
        if [[ "$stop_container" =~ ^[Yy]$ ]]; then
            sudo docker stop "$existing_container"
            sudo docker rm "$existing_container"
        else
            print_warning "Cannot proceed with port $host_port in use"
            return 1
        fi
    fi

    # Build and run options
    read -p "Use default docker build command? (Y/n): " use_default
    if [[ "$use_default" =~ ^[Yy]$ ]]; then
        # Build the image
        print_message "Building Docker image"
        sudo docker build -f "$dockerfile" -t "$image_name" .

        # Run the container
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

    # Verify container status
    print_message "Verifying container status"
    sudo docker ps | grep "$image_name"
    print_message "Container logs:"
    sudo docker logs "$image_name"
}

# Setup Docker deployment
setup_docker_deployment() {
    local repo_path=$1
    
    print_message "Checking for Dockerfile"
    local dockerfiles=($(find . -maxdepth 1 -type f -name "Dockerfile*"))

    if [ ${#dockerfiles[@]} -eq 0 ]; then
        print_error "No Dockerfile found"
        return 1
    fi

    # Handle multiple Dockerfiles
    local selected_dockerfile="Dockerfile"
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

    # Get deployment details
    local exposed_ports=($(get_exposed_ports "$selected_dockerfile"))
    local default_port=${exposed_ports[0]:-3000}
    local project_name=$(basename "$repo_path" | tr '[:upper:]' '[:lower:]')

    read -p "Enter image name (default: $project_name): " image_name
    image_name=${image_name:-$project_name}

    read -p "Enter host port (default: $default_port): " host_port
    host_port=${host_port:-$default_port}

    # Handle container deployment
    manage_container "$image_name" "$host_port" "$default_port" "$selected_dockerfile"
}
