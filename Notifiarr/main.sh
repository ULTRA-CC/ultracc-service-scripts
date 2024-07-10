#!/bin/bash

APPNAME="Notifiarr"
VERSION="2024-07-08"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/.config/notifiarr"
TMPDIR_LOCATION="$HOME/.tmp/notifiarr-$(date +%Y%m%d-%H%M%S)"


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


edit_notifiarr_config() {
    local FILE_PATH="$1"
    local API_KEY_VALUE="$2"
    local PASSWORD="$3"
    local PORT="$4"

    sed -i "s/api_key = \"api-key-from-notifiarr.com\"/api_key = \"$API_KEY_VALUE\"/" "$FILE_PATH"
    sed -i "s/ui_password = \"\"/ui_password = \"$USER:$PASSWORD\"/" "$FILE_PATH"
    sed -i "s/bind_addr = \"0.0.0.0:5454\"/bind_addr = \"0.0.0.0:$PORT\"/" "$FILE_PATH"
}


version_compare() {

    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" != "$1" ]
}


download_latest_binary() {

    LATEST_VERSION=$(curl -s https://api.github.com/repos/Notifiarr/notifiarr/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    mkdir -p ${TMPDIR_LOCATION}/bin
    cd ${TMPDIR_LOCATION}/bin

    wget https://github.com/Notifiarr/notifiarr/releases/download/${LATEST_VERSION}/notifiarr.amd64.linux.gz >/dev/null 2>&1

    gzip -d notifiarr.*
    mv notifiarr.* notifiarr
    chmod +x notifiarr
    mv notifiarr $HOME/bin/
    cd $HOME

}


install_notifiarr() {

    mkdir -p $TMPDIR_LOCATION
    echo -e "${MAGENTA}${BOLD}[STAGE-1] Port selection${STOP_COLOR}"

    # Call port_picker function
    wget -qO ${TMPDIR_LOCATION}/port-selector.sh https://scripts.usbx.me/main-v2/BaseFunctions/port-selector/main.sh
    source ${TMPDIR_LOCATION}/port-selector.sh

    # Download notifiarr.conf from the provided URL
    echo -e "\n${MAGENTA}${BOLD}[STAGE-2] Configure ${APPNAME}${STOP_COLOR}"
    mkdir -p ${CONFIG_DIR}
    wget -O ${CONFIG_DIR}/notifiarr.conf https://scripts.usbx.me/main-v2/Notifiarr/notifiarr.conf >/dev/null 2>&1

    if [[ -f "${CONFIG_DIR}/notifiarr.conf" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] Notifiarr config located at${STOP_COLOR} '${CONFIG_DIR}/notifiarr.conf'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to download Notifiarr config file at${STOP_COLOR} '${CONFIG_DIR}/notifiarr.conf'${RED}${BOLD}. Terminating the script ... Bye!"
        exit 1
    fi

    # Get API and password
    echo
    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your Notifiarr API key: ${STOP_COLOR}" NOTIFIARR_API_KEY && echo

    wget -qO ${TMPDIR_LOCATION}/set-password.sh https://scripts.usbx.me/main-v2/BaseFunctions/set-password/main.sh
    source ${TMPDIR_LOCATION}/set-password.sh

    echo -e "\n${YELLOW}[INFO] Entered API key:${STOP_COLOR} '$NOTIFIARR_API_KEY'"
    echo -e "${YELLOW}[INFO] Entered UI password:${STOP_COLOR} '$CHOSEN_PASSWORD'"


    edit_notifiarr_config "${CONFIG_DIR}/notifiarr.conf" "$NOTIFIARR_API_KEY" "$CHOSEN_PASSWORD" "$SELECTED_PORT"

    # Download binary to correct place
    echo -e "\n${MAGENTA}${BOLD}[STAGE-3] Download Notifiarr binary${STOP_COLOR}"

    download_latest_binary

    BINARY_VERSION=$("${HOME}/bin/notifiarr" -v | awk '{print $2}')

    if [[ -f "${HOME}/bin/notifiarr" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] Notifiarr downloaded binary version at ${STOP_COLOR}'${HOME}/bin/notifiarr': ${BINARY_VERSION}"
    else
        echo -e "${RED}${BOLD}[ERROR] Notifiarr binary NOT found at ${STOP_COLOR}'${HOME}/bin/notifiarr''${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    # Set up systemd
    echo -e "\n${MAGENTA}${BOLD}[STAGE-4] Set up Systemd for ${APPNAME}${STOP_COLOR}"
    cd $HOME/.config/systemd/user/

    cat <<EOF >notifiarr.service
[Unit]
Description=Notifiarr - ${VERSION}

[Service]
ExecStart=$HOME/bin/notifiarr -c $HOME/.config/notifiarr/notifiarr.conf \$DAEMON_OPTS
Restart=always
RestartSec=10
Type=simple
WorkingDirectory=$HOME/bin

[Install]
WantedBy=default.target
EOF

    cd $HOME

    if [[ -f "${HOME}/.config/systemd/user/notifiarr.service" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] Notifiarr systemd file created at ${STOP_COLOR}'${HOME}/.config/systemd/user/notifiarr.service'"
    else
        echo -e "${RED}${BOLD}[ERROR] Notifiarr systemd file NOT found at ${STOP_COLOR}'${HOME}/.config/systemd/user/notifiarr.service'${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    systemctl --user enable notifiarr.service
    systemctl --user start notifiarr.service

    echo -e "\n${MAGENTA}${BOLD}[STAGE-4] Configure Nginx for ${APPNAME}${STOP_COLOR}"
    cd $HOME/.apps/nginx/proxy.d

    # Create Nginx configuration for Notifiarr
    cat <<EOF >notifiarr.conf
location /notifiarr {
    proxy_set_header X-Forwarded-For \$remote_addr;
    set \$notifiarr http://127.0.0.1:$SELECTED_PORT;
    proxy_pass \$notifiarr\$request_uri;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$http_connection;
    proxy_set_header Host \$host;
}

location /notifiarr/api {
    deny all; # remove this line if you really want to expose the API.
    proxy_set_header X-Forwarded-For \$remote_addr;
    set \$notifiarr http://127.0.0.1:$SELECTED_PORT;
    proxy_pass \$notifiarr\$request_uri;
}
EOF

   if [[ -f "${HOME}/.apps/nginx/proxy.d/notifiarr.conf" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] Notifiarr reverse-proxy file created at ${STOP_COLOR}'${HOME}/.apps/nginx/proxy.d/notifiarr.conf'"
    else
        echo -e "${RED}${BOLD}[ERROR] Notifiarr reverse-proxy file NOT found at ${STOP_COLOR}'${HOME}/.apps/nginx/proxy.d/notifiarr.conf'${RED}${BOLD}. Terminating the script ... Bye!$(tput sgr0)"
        exit 1
    fi

    cd $HOME && app-nginx restart

    rm -rf $TMPDIR_LOCATION

    sleep 2
    echo -e "\n${GREEN}${BOLD}[SUCCESS] Notifiarr has been installed successfully. You should now be able to access Notifiarr at - ${STOP_COLOR}'https://$USER.$HOSTNAME.usbx.me/notifiarr'"
}


uninstall_notifiarr() {
    systemctl --user stop notifiarr.service
    systemctl --user disable notifiarr.service >/dev/null 2>&1

    rm -f ${HOME}/.config/systemd/user/notifiarr.service
    rm -f ${HOME}/.apps/nginx/proxy.d/notifiarr.conf

    rm -f ${HOME}/bin/notifiarr

    app-nginx restart && systemctl --user daemon-reload
    if [[ -f ${HOME}/systemd/user/notifiarr.service ]] || [[ -f ${HOME}/.apps/nginx/proxy.d/notifiarr.conf ]] || [[ -f ${HOME}/bin/notifiarr ]]; then
        echo -e "${RED}${BOLD}[ERROR] Notifiarr could not be fully uninstalled."
    else
        echo -e "${GREEN}${BOLD}[SUCCESS] Notifiarr has been uninstalled completely."
    fi
}


reset_notifiarr_password() {
    systemctl --user stop notifiarr.service

    mkdir -p ${TMPDIR_LOCATION}

    wget -qO ${TMPDIR_LOCATION}/set-password.sh https://scripts.usbx.me/main-v2/BaseFunctions/set-password/main.sh
    source ${TMPDIR_LOCATION}/set-password.sh

    echo -e "${YELLOW}[INFO] Entered UI password:${STOP_COLOR} '$CHOSEN_PASSWORD'"

    sed -i "s/ui_password = \"$USER:.*/ui_password = \"$USER:$CHOSEN_PASSWORD\"/" "$HOME/.config/notifiarr/notifiarr.conf"
    echo -e "${GREEN}${BOLD}[SUCCESS] Password change completed"

    systemctl --user restart notifiarr.service

    rm -rf ${TMPDIR_LOCATION}
}


upgrade_notifiarr() {
    systemctl --user stop notifiarr.service

    # Compare existing instance with latest version
    latest_release=$(curl -s https://api.github.com/repos/Notifiarr/notifiarr/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    latest_version=${latest_release#v}
    echo -e "${YELLOW}${BOLD}[INFO] Latest version:${STOP_COLOR} $latest_version"

    installed_version=$(${HOME}/bin/notifiarr -v | awk '{print $2}' | cut -d'-' -f1)
    echo -e "${YELLOW}${BOLD}[INFO] Installed version:${STOP_COLOR} $installed_version"

    if version_compare "$latest_version" "$installed_version"; then
        rm -f ${HOME}/bin/notifiarr
        echo -e "\n${YELLOW}${BOLD}[INFO] Upgrading to version:${STOP_COLOR} ${latest_version}"
        download_latest_binary
    else
        echo -e "\n${YELLOW}${BOLD}[INFO] Already latest version installed${STOP_COLOR} ${installed_version}"
        exit 1
    fi

    # Restart the Notifiarr service after upgrading
    systemctl --user restart notifiarr.service
    sleep 2
    echo "${GREEN}${BOLD}[SUCCESS] Notifiarr upgrade process completed successfully.${STOP_COLOR}"
}

# Function to install, uninstall, reset password, or upgrade for Notifiarr
main_fn() {
    clear
    print_welcome_message
    echo -e "${YELLOW}${BOLD}[WARNING] Disclaimer: This is an unofficial script and is not supported by Ultra.cc staff. Please proceed only if you are experienced with managing such custom installs on your own.${STOP_COLOR}\n"

    echo -e "${BLUE}${BOLD}[LIST] Operations available for ${APPNAME}:${STOP_COLOR}"
    echo "1) Install"
    echo "2) Uninstall"
    echo "3) Reset Password"
    echo -e "4) Upgrade\n"

    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your operation choice${STOP_COLOR} '[1-4]'${BLUE}${BOLD}: ${STOP_COLOR}" OPERATION_CHOICE
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
            reset_${APPNAME,,}_password
            ;;
        4)
            upgrade_${APPNAME,,}
            ;;
        *)
            echo -e "${RED}{BOLD}[ERROR] Invalid choice. Please enter a number between 1 and 4.${STOP_COLOR}"
            exit 1
            ;;
    esac
}

# Call the main function
main_fn

