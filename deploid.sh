#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    echo "Please run: sudo $0"
    exit 1
fi

# Source core modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/colors.sh"
source "$SCRIPT_DIR/core/utils.sh"
source "$SCRIPT_DIR/core/menu.sh"
source "$SCRIPT_DIR/install/git.sh"

# Initialize breadcrumb with "Deploid"
MENU_BREADCRUMB="Deploid"

# Function to handle installation menu
handle_install_menu() {
    update_breadcrumb "Install"

    show_menu "What do you want to install?" "Sudo" "Git" "Docker"
    install_choice=$?

    if [ $install_choice -eq 255 ]; then  # Back
        remove_last_breadcrumb
        return
    fi

    case $install_choice in
        0)  # Sudo
            update_breadcrumb "Sudo"
            show_menu "Installing Sudo" "Continue"
            source "$SCRIPT_DIR/install/sudo.sh"
            install_sudo
            sudo_version=$(sudo -V | head -n1)
            print_message "Yayy! Sudo is installed! ($sudo_version)"
            echo
            print_instruction "Next steps:"
            print_instruction "1. You may need to log out and log back in for sudo permissions to take effect"
            print_instruction "2. Run ./deploid.sh again to install other tools or proceed with setup"
            echo
            read -p "Press Enter to exit..."
            exit 0
            ;;
        1)  # Git
            update_breadcrumb "Git"
            show_menu "Installing Git" "Continue"
            install_git
            git_version=$(git --version 2>/dev/null || echo "unknown")
            print_message "Yayy! Git is installed! ($git_version)"
            echo
            print_instruction "Next steps:"
            print_instruction "1. Run ./deploid.sh and choose 'Setup' > 'Git + SSH' to configure Git"
            print_instruction "2. Or install other tools by running ./deploid.sh again"
            echo
            read -p "Press Enter to exit..."
            exit 0
            ;;
        2)  # Docker
            update_breadcrumb "Docker"
            show_menu "Installing Docker" "Continue"
            source "$SCRIPT_DIR/install/docker.sh"
            install_docker
            docker_version=$(docker --version 2>/dev/null || echo "unknown")
            print_message "Yayy! Docker is installed! ($docker_version)"
            echo
            print_instruction "Next steps:"
            print_instruction "1. Log out and log back in for Docker permissions to take effect"
            print_instruction "2. Run ./deploid.sh and choose 'Setup' > 'Docker' to configure your Docker environment"
            print_instruction "3. Or install other tools by running ./deploid.sh again"
            echo
            read -p "Press Enter to exit..."
            exit 0
            ;;
    esac
}

# Function to handle setup menu
handle_setup_menu() {
    update_breadcrumb "Setup"
    local return_to_main=false

    while true; do
        show_menu "What kind of setup do you want?" "Git + SSH" "Docker" "Node"
        setup_choice=$?

        if [ $setup_choice -eq 255 ]; then  # Back
            remove_last_breadcrumb
            return_to_main=true
            break
        fi

        case $setup_choice in
            0)  # Git + SSH
                update_breadcrumb "Git + SSH"
                show_menu "Git + SSH Setup" "Continue"
                source "$SCRIPT_DIR/core/git.sh"
                setup_ssh_key
                setup_repository
                remove_last_breadcrumb
                ;;
            1)  # Docker
                update_breadcrumb "Docker"
                show_menu "Docker Setup" "Continue"
                source "$SCRIPT_DIR/deployments/docker/deploy.sh"
                deploy_docker "$(pwd)"
                remove_last_breadcrumb
                ;;
            2)  # Node
                update_breadcrumb "Node"
                show_menu "Node Setup" "Continue"
                source "$SCRIPT_DIR/deployments/node/deploy.sh"
                deploy_node "$(pwd)"
                remove_last_breadcrumb
                ;;
        esac
    done

    if [ "$return_to_main" = true ]; then
        remove_last_breadcrumb
    fi
}

# Function to handle update menu
handle_update_menu() {
    update_breadcrumb "Update"
    show_menu "Update Setup" "Continue"
    source "$SCRIPT_DIR/update.sh"
    remove_last_breadcrumb
}

# Main menu loop
while true; do
    show_menu "What do you want to perform?" "Install" "Setup" "Update"
    choice=$?

    # Handle Back/Exit
    if [ $choice -eq 255 ]; then  # Back or Exit from main menu
        clear
        exit 0
    fi

    case $choice in
        0)  # Install
            handle_install_menu
            ;;
        1)  # Setup
            handle_setup_menu
            ;;
        2)  # Update
            handle_update_menu
            ;;
    esac
done
