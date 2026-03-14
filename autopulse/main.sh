#!/bin/bash

set -euo pipefail


APPNAME="Autopulse"
VERSION="2026-03-14"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/.apps/autopulse"
TMPDIR_LOCATION="$HOME/.tmp/autopulse-$(date +%Y%m%d-%H%M%S)"

# Global arrays for multi-target support
declare -a TARGET_TYPES=()
declare -a TARGET_URLS=()
declare -a TARGET_TOKENS=()


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


download_latest_binary() {
    LATEST_VERSION=$(curl -s https://api.github.com/repos/dan-online/autopulse/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    mkdir -p ${TMPDIR_LOCATION}/bin
    cd ${TMPDIR_LOCATION}/bin

    wget -qO "${TMPDIR_LOCATION}/bin/autopulse.tar.gz" "https://github.com/dan-online/autopulse/releases/download/${LATEST_VERSION}/autopulse-x86_64-unknown-linux-musl.tar.gz" >/dev/null 2>&1

    tar -xzf autopulse.tar.gz
    chmod +x autopulse
    mv autopulse $HOME/bin/
    cd $HOME
}


create_config_file() {
    # Build targets section from arrays
    local targets_block=""
    for i in "${!TARGET_TYPES[@]}"; do
        targets_block+="[targets.${TARGET_TYPES[$i]}]
type = \"${TARGET_TYPES[$i]}\"
url = \"${TARGET_URLS[$i]}\"
token = \"${TARGET_TOKENS[$i]}\"

"
    done

    cat <<EOF | tee "${CONFIG_DIR}"/config.toml >/dev/null
################################################################
# This is just a basic config file. For more options, see:     #
# https://github.com/dan-online/autopulse                     #
################################################################

[app]
hostname = "0.0.0.0"
port = ${port}
database_url = "sqlite://${CONFIG_DIR}/autopulse.db"

[auth]
username = "${USER}"
password = "${CHOSEN_PASSWORD}"

[opts]
check_path = true
max_retries = 5
default_timer_wait = 60
cleanup_days = 10
log_file = "${CONFIG_DIR}/autopulse.log"
log_file_rollover = "daily"

[triggers.sonarr]
type = "sonarr"

[triggers.radarr]
type = "radarr"

[triggers.lidarr]
type = "lidarr"

[triggers.readarr]
type = "readarr"

[triggers.manual]
type = "manual"

${targets_block}
EOF
}

systemd_service_file() {
    cat <<EOF | tee "${HOME}"/.config/systemd/user/autopulse.service >/dev/null
[Unit]
Description=autopulse
After=network-online.target
[Service]
Type=simple
ExecStart=%h/bin/autopulse --config="%h/.apps/autopulse/config.toml"
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

    declare -a ADDED_SERVERS=()

    while true; do
        echo -e "\n${YELLOW}${BOLD}Which media server are you planning to use ${APPNAME} with?${STOP_COLOR}"

        echo -e "${BLUE}${BOLD}[LIST] Media server applications available to use with ${APPNAME}:${STOP_COLOR}"
        echo "1) Plex Media Server"
        echo "2) Emby"
        echo -e "3) Jellyfin\n"

        if [[ ${#ADDED_SERVERS[@]} -gt 0 ]]; then
            echo -e "${YELLOW}${BOLD}[INFO] Already added: ${ADDED_SERVERS[*]}${STOP_COLOR}"
        fi

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
                continue
                ;;
        esac

        # Check if this server was already added
        local already_added=false
        for added in "${ADDED_SERVERS[@]+"${ADDED_SERVERS[@]}"}"; do
            if [[ "${added}" == "${server}" ]]; then
                already_added=true
                break
            fi
        done

        if [[ "${already_added}" == true ]]; then
            echo -e "${YELLOW}${BOLD}[INFO] ${server} has already been added. Please choose a different server.${STOP_COLOR}"
            continue
        fi

        if [ -z "${serverport}" ]; then
            echo -e "${RED}${BOLD}[ERROR] ${server} port not found.${STOP_COLOR}"
            exit 1
        fi

        while true; do
            echo
            read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter the ${server} authentication token: ${STOP_COLOR}" servertoken
            echo
            if curl -fs "${auth}=${servertoken}" > /dev/null; then
                break
            else
                echo -e "${RED}${BOLD}[ERROR] ${server} authentication failed, please try again.${STOP_COLOR}"
            fi
        done

        echo -e "${YELLOW}${BOLD}[INFO] Authentication successful. Proceeding with ${server}.${STOP_COLOR}"

        # Store in global arrays
        TARGET_TYPES+=("${target}")
        TARGET_URLS+=("${url}")
        TARGET_TOKENS+=("${servertoken}")
        ADDED_SERVERS+=("${server}")

        # Check if all 3 servers have been added
        if [[ ${#ADDED_SERVERS[@]} -ge 3 ]]; then
            break
        fi

        echo
        read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Would you like to add another media server target? [y/N]: ${STOP_COLOR}" ADD_ANOTHER
        if [[ "${ADD_ANOTHER,,}" != "y" ]]; then
            break
        fi
    done
}


install_autopulse() {
    if [ -d "${CONFIG_DIR}" ]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config already present at -${STOP_COLOR} '${CONFIG_DIR}'"
        echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    mkdir -p $TMPDIR_LOCATION
    echo -e "${MAGENTA}${BOLD}[STAGE-1] Port selection${STOP_COLOR}"

    # Call port_picker function
    wget -qO ${TMPDIR_LOCATION}/port-selector.sh https://scripts.usbx.me/main-v2/BaseFunctions/port-selector/main.sh
    source ${TMPDIR_LOCATION}/port-selector.sh

    port="${SELECTED_PORT}"

    echo -e "\n${MAGENTA}${BOLD}[STAGE-2] Configure ${APPNAME}${STOP_COLOR}"
    mkdir -p ${CONFIG_DIR}

    # Get password
    wget -qO ${TMPDIR_LOCATION}/set-password.sh https://scripts.usbx.me/main-v2/BaseFunctions/set-password/main.sh
    source ${TMPDIR_LOCATION}/set-password.sh

    echo -e "${YELLOW}[INFO] Entered password:${STOP_COLOR} '$CHOSEN_PASSWORD'"

    # Connect autopulse with media app
    connect_with_media_server

    # Create config file
    create_config_file

    if [[ -f "${CONFIG_DIR}/config.toml" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config located at${STOP_COLOR} '${CONFIG_DIR}/config.toml'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to create ${APPNAME} config file at${STOP_COLOR} '${CONFIG_DIR}/config.toml'${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    # Download binary to correct place
    echo -e "\n${MAGENTA}${BOLD}[STAGE-3] Download ${APPNAME} binary${STOP_COLOR}"

    download_latest_binary

    BINARY_VERSION=$("${HOME}/bin/autopulse" --version 2>/dev/null | head -1) || BINARY_VERSION="unknown"

    if [[ -f "${HOME}/bin/autopulse" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} downloaded binary version at ${STOP_COLOR}'${HOME}/bin/autopulse': ${BINARY_VERSION}"
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} binary NOT found at ${STOP_COLOR}'${HOME}/bin/autopulse'${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    echo -e "\n${MAGENTA}${BOLD}[STAGE-4] Configure Systemd service for ${APPNAME}${STOP_COLOR}"
    systemd_service_file
    cd $HOME
    if [[ -f "${HOME}/.config/systemd/user/autopulse.service" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} systemd file created at ${STOP_COLOR}'${HOME}/.config/systemd/user/autopulse.service'"
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} systemd file NOT found at ${STOP_COLOR}'${HOME}/.config/systemd/user/autopulse.service'${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    rm -rf $TMPDIR_LOCATION

    systemctl --user enable autopulse.service
    systemctl --user start autopulse.service

    if systemctl --user is-active --quiet "autopulse.service"; then
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been installed successfully.${STOP_COLOR}"
        echo "[INFO] Authentication: ${USER} / ${CHOSEN_PASSWORD}"
        echo "[INFO] Configured targets:"
        for i in "${!TARGET_TYPES[@]}"; do
            echo "    [+] ${TARGET_TYPES[$i]}: ${TARGET_URLS[$i]}"
        done
        echo "[INFO] Webhook URLs:"
        echo "    [+] Sonarr:  http://172.17.0.1:${port}/triggers/sonarr"
        echo "    [+] Radarr:  http://172.17.0.1:${port}/triggers/radarr"
        echo "    [+] Lidarr:  http://172.17.0.1:${port}/triggers/lidarr"
        echo "    [+] Readarr: http://172.17.0.1:${port}/triggers/readarr"
        echo "    [+] Manual:  http://172.17.0.1:${port}/triggers/manual"
        echo "    [+] Log file: ${CONFIG_DIR}/autopulse.log"
        exit 0
    else
        echo -e "${RED}${BOLD}[ERROR] Unable to start ${APPNAME} systemd service. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

}

uninstall_autopulse() {
    systemctl --user stop autopulse.service
    systemctl --user disable autopulse.service >/dev/null 2>&1

    rm -f ${HOME}/.config/systemd/user/autopulse.service
    rm -f ${HOME}/bin/autopulse
    systemctl --user daemon-reload

    if [[ -d "${CONFIG_DIR}" ]]; then
        echo
        read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Do you want to remove the config and database at${STOP_COLOR} '${CONFIG_DIR}'${BLUE}${BOLD}? [y/N]: ${STOP_COLOR}" REMOVE_CONFIG
        if [[ "${REMOVE_CONFIG,,}" == "y" ]]; then
            rm -rf "${CONFIG_DIR}"
            echo -e "${YELLOW}${BOLD}[INFO] Config directory removed.${STOP_COLOR}"
        else
            echo -e "${YELLOW}${BOLD}[INFO] Config directory preserved at${STOP_COLOR} '${CONFIG_DIR}'"
        fi
    fi

    if [[ -f ${HOME}/.config/systemd/user/autopulse.service ]] || [[ -f ${HOME}/bin/autopulse ]]; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} could not be fully uninstalled.${STOP_COLOR}"
    else
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been uninstalled completely.${STOP_COLOR}"
    fi
}


upgrade_autopulse() {
    if [[ -f "${HOME}/.config/systemd/user/autopulse.service" ]]; then
        OLD_VERSION=$("${HOME}/bin/autopulse" --version 2>/dev/null | head -1) || OLD_VERSION="unknown"
        echo -e "${YELLOW}${BOLD}[INFO] Current version: ${OLD_VERSION}${STOP_COLOR}"
        echo -e "${YELLOW}${BOLD}[INFO] Stopping ${APPNAME} systemd service.${STOP_COLOR}"
        systemctl --user stop autopulse.service
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} systemd file NOT found at ${STOP_COLOR}'${HOME}/.config/systemd/user/autopulse.service'${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    # Backup config
    if [[ -f "${CONFIG_DIR}/config.toml" ]]; then
        cp "${CONFIG_DIR}/config.toml" "${CONFIG_DIR}/config.toml.bak"
        echo -e "${YELLOW}${BOLD}[INFO] Config backed up to${STOP_COLOR} '${CONFIG_DIR}/config.toml.bak'"
    fi

    # Download latest binary
    download_latest_binary

    NEW_VERSION=$("${HOME}/bin/autopulse" --version 2>/dev/null | head -1) || NEW_VERSION="unknown"

    systemctl --user restart autopulse.service

    if systemctl --user is-active --quiet "autopulse.service"; then
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been upgraded successfully.${STOP_COLOR}"
        echo -e "${GREEN}${BOLD}[INFO] ${OLD_VERSION} -> ${NEW_VERSION}${STOP_COLOR}"
        exit 0
    else
        echo -e "${RED}${BOLD}[ERROR] Unable to start ${APPNAME} systemd service. Terminating the script ... Bye!${STOP_COLOR}"
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
            echo -e "${RED}${BOLD}[ERROR] Invalid choice. Please enter a number between 1 and 3.${STOP_COLOR}"
            exit 1
            ;;
    esac
}


# Call the main function
main_fn
