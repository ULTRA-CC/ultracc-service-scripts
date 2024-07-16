#!/bin/bash

APPNAME="Recyclarr"
VERSION="2024-07-16"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/.apps/recyclarr"
BIN_DIR="$HOME/bin"
TMPDIR_LOCATION="$HOME/.tmp/recyclarr-$(date +%Y%m%d-%H%M%S)"

DOWNLOAD_URL="https://github.com/recyclarr/recyclarr/releases/latest/download/recyclarr-linux-x64.tar.xz"


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


install_recyclarr() {
    if [ -d "${CONFIG_DIR}" ]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config already present at -${STOP_COLOR} '${CONFIG_DIR}'"
        echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!"
        exit 1
    fi
    wget "$DOWNLOAD_URL" -O - 2>/dev/null | tar xJ --overwrite -C "$BIN_DIR" > /dev/null 2>&1

    mkdir -p "$CONFIG_DIR"
    echo -e '\nexport DOTNET_GCHeapHardLimit=10000000\nexport RECYCLARR_APP_DATA="$HOME/.apps/recyclarr/"' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"

    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been installed successfully."
    exec "$SHELL"
}


uninstall_recyclarr() {
    rm -rf "$BIN_DIR/recyclarr"

    rm -rf "$CONFIG_DIR"

    # Remove entries from bashrc
    sed -i '/DOTNET_GCHeapHardLimit/d' "$HOME/.bashrc"
    sed -i '/RECYCLARR_APP_DATA/d' "$HOME/.bashrc"

    if [[ -d "${CONFIG_DIR}" ]] || [[ -f ${HOME}/bin/recyclarr ]]; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} could not be fully uninstalled."
    else
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been uninstalled completely."
    fi
}


main_fn() {
    clear
    print_welcome_message
    echo -e "${YELLOW}${BOLD}[WARNING] Disclaimer: This is an unofficial script and is not supported by Ultra.cc staff. Please proceed only if you are experienced with managing such custom installs on your own.${STOP_COLOR}\n"

    echo -e "${BLUE}${BOLD}[LIST] Operations available for ${APPNAME}:${STOP_COLOR}"
    echo "1) Install"
    echo -e "2) Uninstall\n"

    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your operation choice${STOP_COLOR} '[1-2]'${BLUE}${BOLD}: ${STOP_COLOR}" OPERATION_CHOICE
    echo

    # Check user choice and execute function
    case "$OPERATION_CHOICE" in
        1)
            install_${APPNAME,,}
            ;;
        2)
            uninstall_${APPNAME,,}
            ;;
        *)
            echo -e "${RED}{BOLD}[ERROR] Invalid choice. Please enter a number 1 or 2.${STOP_COLOR}"
            exit 1
            ;;
    esac
}

# Call the main function
main_fn
