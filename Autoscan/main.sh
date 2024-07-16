#!/bin/bash

set -euo pipefail


APPNAME="Autoscan"
VERSION="2024-07-11"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/.apps/autoscan"
TMPDIR_LOCATION="$HOME/.tmp/autoscan-$(date +%Y%m%d-%H%M%S)"


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


download_latest_binary() {
    LATEST_VERSION=$(curl -s https://api.github.com/repos/Cloudbox/autoscan/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    mkdir -p ${TMPDIR_LOCATION}/bin
    cd ${TMPDIR_LOCATION}/bin

    wget -qO "${TMPDIR_LOCATION}/bin/autoscan" https://github.com/Cloudbox/autoscan/releases/download/${LATEST_VERSION}/autoscan_${LATEST_VERSION}_linux_amd64 >/dev/null 2>&1

    chmod +x autoscan
    mv autoscan $HOME/bin/
    cd $HOME
}


create_config_file() {
    cat <<EOF | tee "${HOME}"/.apps/autoscan/config.yml >/dev/null
################################################################
# This is just a basic config file. For more options, see:     #
# https://github.com/Cloudbox/autoscan/blob/master/README.md   #
################################################################

minimum-age: 2m30s
scan-delay: 15s
scan-stats: 15m

authentication:
  username: ${USER}
  password: ${CHOSEN_PASSWORD}

port: ${port}

triggers:
  manual:
    priority: 0

  sonarr:
    - name: sonarr
      priority: 1

  radarr:
    - name: radarr
      priority: 1

targets:
  ${target}:
    - url: ${url}
      token: ${servertoken}

EOF
}

systemd_service_file() {
    cat <<EOF | tee "${HOME}"/.config/systemd/user/autoscan.service >/dev/null
[Unit]
Description=autoscan
After=network-online.target
[Service]
Type=simple
ExecStart=%h/bin/autoscan --config="%h/.apps/autoscan/config.yml" \
    --database="%h/.apps/autoscan/autoscan.db" \
    --log="%h/.apps/autoscan/activity.log"
[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
}


connect_with_media_server() {
    # Retrieve ports for each media server
    plexport=$(app-ports show | grep "Plex Media Server" | head -n 1 | awk '{print $1}') || plexport=''
    embyport=$(app-ports show | grep "Emby" | head -n 1 | awk '{print $1}') || embyport=''
    jellyport=$(app-ports show | grep "Jellyfin" | head -n 1 | awk '{print $1}') || jellyport=''

    echo -e "\n${YELLOW}${BOLD}Which media server are you planning to use autoscan with?${STOP_COLOR}"

    echo -e "${BLUE}${BOLD}[LIST] Media server applications available to use with ${APPNAME}:${STOP_COLOR}"
    echo "1) Plex Media Server"
    echo "2) Emby"
    echo -e "3) Jellyfin\n"

    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your application choice${STOP_COLOR} '[1-3]'${BLUE}${BOLD}: ${STOP_COLOR}" MEDIA_SERVER_APP

    case "${MEDIA_SERVER_APP}" in
        1)
            server="Plex Media Server"
            target='plex'
            serverport="${plexport}"
            url="http://172.17.0.1:${serverport}"
            auth="${url}/?X-Plex-Token"
            ;;
        2)
            server="Emby"
            target='emby'
            serverport="${embyport}"
            url="http://172.17.0.1:${serverport}"
            auth="${url}/System/Info?Api_key"
            ;;
        3)
            server="Jellyfin"
            target='jellyfin'
            serverport="${jellyport}"
            url="http://172.17.0.1:${serverport}/jellyfin"
            auth="${url}/System/Info?Api_key"
            ;;
        *)
            echo -e "${RED}${BOLD}[ERROR] Invalid option. Please enter a number between 1 and 3.${STOP_COLOR}"
            return 1
            ;;
    esac

    if [ -z "${serverport}" ]; then
        echo -e "${RED}${BOLD}[ERROR] ${MEDIA_SERVER_APP} port not found.${STOP_COLOR}"
        exit 1
    fi

    while true; do
        echo
        read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter the ${MEDIA_SERVER_APP} authentication token: ${STOP_COLOR}" servertoken
        echo
        if curl -fs "${auth}=${servertoken}" > /dev/null; then
            break
        else
            echo -e "${RED}${BOLD}[ERROR] ${MEDIA_SERVER_APP} authentication failed, please try again.${STOP_COLOR}"
        fi
    done

    echo -e "${YELLOW}${BOLD}[INFO] Authentication successful. Proceeding with ${MEDIA_SERVER_APP}.${STOP_COLOR}"
}


install_autoscan() {
    if [ -d "${CONFIG_DIR}" ]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config already present at -${STOP_COLOR} '${CONFIG_DIR}'"
        echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!"
        exit 1
    fi

    mkdir -p $TMPDIR_LOCATION
    echo -e "${MAGENTA}${BOLD}[STAGE-1] Port selection${STOP_COLOR}"

    # Call port_picker function
    wget -qO ${TMPDIR_LOCATION}/port-selector.sh https://scripts.usbx.me/main-v2/BaseFunctions/port-selector/main.sh
    source ${TMPDIR_LOCATION}/port-selector.sh

    echo -e "\n${MAGENTA}${BOLD}[STAGE-2] Configure ${APPNAME}${STOP_COLOR}"
    mkdir -p ${CONFIG_DIR}

    # Get password
    wget -qO ${TMPDIR_LOCATION}/set-password.sh https://scripts.usbx.me/main-v2/BaseFunctions/set-password/main.sh
    source ${TMPDIR_LOCATION}/set-password.sh

    echo -e "${YELLOW}[INFO] Entered password:${STOP_COLOR} '$CHOSEN_PASSWORD'"

    # connect autoscan with media app
    connect_with_media_server

    # create config file
    create_config_file

    if [[ -f "${CONFIG_DIR}/autoscan.conf" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config located at${STOP_COLOR} '${CONFIG_DIR}/autoscan.conf'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to download ${APPNAME} config file at${STOP_COLOR} '${CONFIG_DIR}/autoscan.conf'${RED}${BOLD}. Terminating the script ... Bye!"
        exit 1
    fi

    # Download binary to correct place
    echo -e "\n${MAGENTA}${BOLD}[STAGE-3] Download ${APPNAME} binary${STOP_COLOR}"

    download_latest_binary

    BINARY_VERSION=$("${HOME}/bin/autoscan" --version | awk '{print $1}')

    if [[ -f "${HOME}/bin/autoscan" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} downloaded binary version at ${STOP_COLOR}'${HOME}/bin/autoscan': ${BINARY_VERSION}"
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} binary NOT found at ${STOP_COLOR}'${HOME}/bin/autoscan''${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    echo -e "\n${MAGENTA}${BOLD}[STAGE-4] Configure Systemd service for ${APPNAME}${STOP_COLOR}"
    systemd_service_file
    cd $HOME
    if [[ -f "${HOME}/.config/systemd/user/autoscan.service" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} systemd file created at ${STOP_COLOR}'${HOME}/.config/systemd/user/autoscan.service'"
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} systemd file NOT found at ${STOP_COLOR}'${HOME}/.config/systemd/user/autoscan.service'${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    rm -rf $TMPDIR_LOCATION

    systemctl --user enable autoscan.service
    systemctl --user start autoscan.service

    if systemctl --user is-active --quiet "autoscan.service"; then
        echo -e "${GREEN}${BOLD}[SUCCESS] Autoscan has been installed successfully."
        echo "[INFO] Webhook URLs:"
        echo "    [+] Sonarr: http://172.17.0.1:${port}/triggers/sonarr"
        echo "    [+] Radarr: http://172.17.0.1:${port}/triggers/radarr"
        exit 0
    else
        echo "${RED}${BOLD}[ERROR]: Unable to start Autoscan systemd service. Terminating the script ... Bye!"
        exit 1
    fi

}

uninstall_autoscan() {
    systemctl --user stop autoscan.service
    systemctl --user disable autoscan.service >/dev/null 2>&1

    rm -f ${HOME}/.config/systemd/user/autoscan.service

    rm -f ${HOME}/bin/autoscan

    systemctl --user daemon-reload
    if [[ -f ${HOME}/systemd/user/autoscan.service ]] || [[ -f ${HOME}/bin/autoscan ]]; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} could not be fully uninstalled."
    else
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been uninstalled completely."
    fi
}


upgrade_autoscan() {
    if [[ -f "${HOME}/.config/systemd/user/autoscan.service" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] Stopping ${APPNAME} systemd file.${STOP_COLOR}'"
        systemctl --user stop autoscan.service
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} systemd file NOT found at ${STOP_COLOR}'${HOME}/.config/systemd/user/autoscan.service'${RED}${BOLD}. Terminating the script ... Bye!"
        exit 1
    fi

    #download latest binary
    download_latest_binary

    systemctl --user restart autoscan.service

    if systemctl --user is-active --quiet "autoscan.service"; then
        echo -e "${GREEN}${BOLD}[SUCCESS] Autoscan has been upgraded successfully."
        exit 0
    else
        echo "${RED}${BOLD}[ERROR]: Unable to start Autoscan systemd service. Terminating the script ... Bye!"
        exit 1
    fi
}


main_fn() {
    clear
    print_welcome_message
    echo -e "${YELLOW}${BOLD}[WARNING] Disclaimer: This is an unofficial script and is not supported by Ultra.cc staff. Please proceed only if you are experienced with managing such custom installs on your own.${STOP_COLOR}\n"

    echo -e "${BLUE}${BOLD}[LIST] Operations available for ${APPNAME}:${STOP_COLOR}"
    echo "1) Install"
    echo "2) Uninstall"
    echo -e "3) Upgrade\n"

    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your operation choice${STOP_COLOR} '[1-3]'${BLUE}${BOLD}: ${STOP_COLOR}" OPERATION_CHOICE
    echo

    # Check user choice and execute function
    case "$OPERATION_CHOICE" in
        1)
            install_${APPNAME,,}
            ;;
        2)
            uninstall_${APPNAME,,}
            ;;
        3)
            upgrade_${APPNAME,,}
            ;;
        *)
            echo -e "${RED}{BOLD}[ERROR] Invalid choice. Please enter a number between 1 and 3.${STOP_COLOR}"
            exit 1
            ;;
    esac
}


# Call the main function
main_fn
