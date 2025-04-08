#!/bin/bash

# Source colors for menu styling
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Clear screen and print header
clear_and_print_header() {
    clear
    print_message "Welcome to Deploid! Your AI Buddy for Quick and Easy Deployment!"
    echo
}

# Interactive menu selection function
select_option() {
    local options=("$@")
    local is_main_menu=0
    
    # Check if this is the main menu by looking at the breadcrumb
    if [ "$MENU_BREADCRUMB" = "Deploid" ]; then
        is_main_menu=1
        options+=("Exit")
    else
        options+=("Back" "Exit")
    fi
    
    local selected=0
    local ENTER=$'\n'
    local key

    # Hide cursor
    tput civis

    # Clear screen area for menu
    for ((i=0; i<${#options[@]}; i++)); do
        echo -en "\033[K\n"
    done
    echo -en "\033[${#options[@]}A"

    # Print initial menu
    print_menu() {
        for ((i=0; i<${#options[@]}; i++)); do
            echo -en "\033[K"
            if [ $i -eq $selected ]; then
                echo -e "\033[36m> ${options[i]}\033[0m"
            else
                echo -e "  ${options[i]}"
            fi
        done
        echo -en "\033[${#options[@]}A"
    }

    print_menu

    while true; do
        read -rsn1 key
        case "$key" in
            $'\x1B')  # ESC sequence
                read -rsn2 key
                case "$key" in
                    '[A')  # Up arrow
                        ((selected--))
                        [ $selected -lt 0 ] && selected=$((${#options[@]}-1))
                        print_menu
                        ;;
                    '[B')  # Down arrow
                        ((selected++))
                        [ $selected -eq ${#options[@]} ] && selected=0
                        print_menu
                        ;;
                esac
                ;;
            "")  # Enter key
                echo -en "\033[${#options[@]}B"
                tput cnorm
                # Check if Exit was selected
                if [ "${options[$selected]}" = "Exit" ]; then
                    clear
                    exit 0
                elif [ "${options[$selected]}" = "Back" ]; then
                    return 255  # Special return code for Back
                else
                    return $selected
                fi
                ;;
        esac
    done
}

# Helper function to display menu and get selection
show_menu() {
    local title=$1
    shift
    local options=("$@")
    
    # Clear screen and show header
    clear_and_print_header
    
    # Show navigation breadcrumb if it exists
    if [ -n "$MENU_BREADCRUMB" ]; then
        echo -e "${BLUE}$MENU_BREADCRUMB${NC}"
        echo
    fi
    
    echo "$title"
    select_option "${options[@]}"
    return $?
}

# Update breadcrumb trail
update_breadcrumb() {
    local new_item=$1
    if [ "$MENU_BREADCRUMB" = "Deploid" ]; then
        MENU_BREADCRUMB="Deploid > $new_item"
    else
        MENU_BREADCRUMB="$MENU_BREADCRUMB > $new_item"
    fi
}

# Remove last item from breadcrumb
remove_last_breadcrumb() {
    if [ "$MENU_BREADCRUMB" != "Deploid" ]; then
        # Remove everything after and including the last ">"
        MENU_BREADCRUMB=${MENU_BREADCRUMB%\ >*}
        # If we removed everything, reset to "Deploid"
        if [ -z "$MENU_BREADCRUMB" ]; then
            MENU_BREADCRUMB="Deploid"
        fi
    fi
}
