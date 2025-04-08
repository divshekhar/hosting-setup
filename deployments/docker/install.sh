#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../../core/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/system.sh"

install_docker() {
    if ! command_exists docker; then
        print_message "Installing Docker..."
        if ! package_installed docker-ce; then
            sudo apt-get install -y ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
              "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi

        setup_docker_permissions
    else
        print_instruction "Docker is already installed ($(docker --version))"
        setup_docker_permissions
    fi
}

setup_docker_permissions() {
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        print_instruction "Adding user to docker group..."
        sudo usermod -aG docker "$USER"
        print_instruction "Please note: Docker permission changes will take effect after you log out and back in"
    fi
}