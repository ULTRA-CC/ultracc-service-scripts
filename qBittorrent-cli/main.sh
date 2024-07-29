#!/bin/bash

APPNAME="qBittorrent-cli"
VERSION="2024-07-08"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/.config/qbt"
TMPDIR_LOCATION="$HOME/.tmp/qbt-$(date +%Y%m%d-%H%M%S)"


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


download_latest_binary() {
    LATEST_VERSION=$(curl -s https://api.github.com/repos/ludviglundgren/qbittorrent-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

    cd ${TMPDIR_LOCATION}

    wget https://github.com/ludviglundgren/qbittorrent-cli/releases/download/v${LATEST_VERSION}/qbittorrent-cli_${LATEST_VERSION}_linux_amd64.tar.gz >/dev/null 2>&1
    tar -xzvf qbittorrent-cli_* >/dev/null 2>&1
    chmod +x qbt
    mv qbt $HOME/bin/
    cd $HOME
}


edit_config_file() {
    PORT=$1
    USERNAME=$2
    PASSWORD=$3

    sed -i "s/<WEBUI-PORT>/${PORT}/" ${CONFIG_DIR}/.qbt.toml
    sed -i "s/<USERNAME>/${USERNAME}/" ${CONFIG_DIR}/.qbt.toml
    sed -i "s/<PASSWORD>/${PASSWORD}/" ${CONFIG_DIR}/.qbt.toml
}


install_qbittorrent-cli() {
    mkdir -p $TMPDIR_LOCATION

    echo -e "${MAGENTA}${BOLD}[STAGE-1] Download latest ${APPNAME} binary and default configuration${STOP_COLOR}"
    download_latest_binary

    if [[ -f $HOME/bin/qbt ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} latest binary present at:${STOP_COLOR} '$HOME/bin/qbt'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to download ${APPNAME} binary, check manually. Terminating the script ... Bye!"
        exit 1
    fi

    mkdir -p ${CONFIG_DIR}
    wget -O ${CONFIG_DIR}/.qbt.toml https://scripts.usbx.me/main-v2/qBittorrent-cli/qbt.toml.default >/dev/null 2>&1

    if [[ -f "${CONFIG_DIR}/.qbt.toml" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config located at${STOP_COLOR} '${CONFIG_DIR}/.qbt.toml'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to download ${APPNAME} config file at${STOP_COLOR} '${CONFIG_DIR}/.qbt.toml'${RED}${BOLD}. Terminating the script ... Bye!"
        exit 1
    fi

    echo -e "\n${MAGENTA}${BOLD}[STAGE-2] Edit default config with qBittorrent details${STOP_COLOR}"
    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your qBittorrent password available in UCP${BLUE}${BOLD}: ${STOP_COLOR}" QBIT_PASS
    QBIT_PORT=$(/usr/bin/app-ports show | grep qBittorrent | awk '{print $1}')
    QBIT_USERNAME="$USER"

    if [[ -n "$QBIT_PORT" && -n "$QBIT_USERNAME" && -n "$QBIT_PASS" ]]; then
        edit_config_file ${QBIT_PORT} ${QBIT_USERNAME} ${QBIT_PASS}
        echo -e "${YELLOW}${BOLD}[INFO] Config updated with qBittorrent details.${STOP_COLOR}"
    else
        echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!"
        exit 1
    fi

    rm -rf $TMPDIR_LOCATION

    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been installed successfully. Try this  command for usage instructions:${STOP_COLOR} 'qbt help'"
    echo -e "${YELLOW}${BOLD}   [+] It's official documentation is available here - https://github.com/ludviglundgren/qbittorrent-cli"
}


uninstall_qbittorrent-cli() {
    rm -f ${HOME}/bin/qbt
    if [[ -f ${HOME}/bin/qbt ]]; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} could not be fully uninstalled."
    else
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been uninstalled completely. It's config file still present at:${STOP_COLOR} '${CONFIG_DIR}/.qbt.toml'"
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
