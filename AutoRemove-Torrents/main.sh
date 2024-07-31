#!/bin/bash

APPNAME="AutoRemove-Torrents"
VERSION="2024-07-29"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/.config/autoremove-torrents"
TMPDIR_LOCATION="$HOME/.tmp/autoremove-torrents-$(date +%Y%m%d-%H%M%S)"
CONFIG_FILE="$CONFIG_DIR/config.yml"
PYTHON_PATH=$(which python3)

print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


download_latest_config() {
    git clone https://github.com/jerrymakesjelly/autoremove-torrents.git ${TMPDIR_LOCATION}/autoremove-torrents >/dev/null 2>&1
    cd ${TMPDIR_LOCATION}/autoremove-torrents

    pip install autoremove-torrents >/dev/null 2>&1
    python3 setup.py install --user >/dev/null 2>&1

    cp -a ${TMPDIR_LOCATION}/autoremove-torrents/* ${CONFIG_DIR}/

    wget -O ${CONFIG_DIR}/config.yml https://scripts.usbx.me/main-v2/AutoRemove-Torrents/config.yml.example >/dev/null 2>&1
}


install_autoremove-torrents() {
    echo -e "\n${BLUE}${BOLD}[LIST] Prerequisites for ${APPNAME}${STOP_COLOR}"
    echo "1. Python version 3.8.1 or above."
    echo -e "2. A running torrent client - Deluge, qBit or Transmission.\n"

    sleep 3

    if [ -z "$PYTHON_PATH" ]; then
        echo "${RED}${BOLD}[ERROR] Python 3 is not installed. Terminating the script ... Bye!"
        exit 1
    fi

    mkdir -p ${CONFIG_DIR}
    mkdir -p ${TMPDIR_LOCATION}

    echo -e "${MAGENTA}${BOLD}[STAGE-1] Check Installed Python version${STOP_COLOR}"
    PY_VERSION_CHECK=$($PYTHON_PATH -c 'import sys; print(sys.version_info >= (3, 8))')
    if [[ "$PY_VERSION_CHECK" == "True" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] Installed Python version is 3.8 or larger.${STOP_COLOR}"
    else
        echo -e "${YELLOW}${BOLD}[[ WARNING ]] Python version is less than 3.8. Hence, running python install script for latest version ...."
        sleep 5
        wget -qO ${TMPDIR_LOCATION}/python-installer.sh https://scripts.usbx.me/util-v2/LanguageInstaller/Python-Installer/main.sh
        source ${TMPDIR_LOCATION}/python-installer.sh
        source ~/.profile

        #recheck python version
        PYTHON_PATH=$(which python3)
        PY_VERSION_CHECK=$($PYTHON_PATH -c 'import sys; print(sys.version_info >= (3, 8))')
        if [[ "$PY_VERSION_CHECK" == "True" ]]; then
            echo -e "\n${YELLOW}${BOLD}[INFO] Installed Python version is 3.8 or larger.${STOP_COLOR}"
            APPNAME="AutoRemove-Torrents"
            echo -e "\n${GREEN}${BOLD}[INFO] Resuming ${APPNAME} installation process now !!!\n"
        else
            echo "${RED}${BOLD}[ERROR] Still Python version is lower than 3.8. Terminating the script ... Bye!"
            exit 1
        fi
    fi

    echo -e "${MAGENTA}${BOLD}[STAGE-2] Download latest ${APPNAME} configuration${STOP_COLOR}"
    download_latest_config

    if [[ -f ${CONFIG_DIR}/config.yml ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config file present at:${STOP_COLOR} '${CONFIG_DIR}/config.yml'"
        echo -e "${YELLOW}${BOLD}  [+] Edit the template config file with the help of ${APPNAME} Manage documentation, here -${STOP_COLOR} https://autoremove-torrents.readthedocs.io/en/latest/config.html"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to create ${APPNAME} config, check manually. Terminating the script ... Bye!"
        exit 1
    fi

    rm -rf ${TMPDIR_LOCATION}

    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been installed successfully.${STOP_COLOR}"
    echo -e "${YELLOW}${BOLD}   [+] Run command to confirm the installation:${STOP_COLOR} 'autoremove-torrents -v'"
}


uninstall_autoremove-torrents() {
    rm -rf ${CONFIG_DIR}
    if [[ -d ${CONFIG_DIR} ]]; then
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
