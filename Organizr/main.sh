#!/bin/bash


APPNAME="Organizr"
VERSION="2024-07-15"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/www/organizr"
TMPDIR_LOCATION="$HOME/.tmp/organizr-$(date +%Y%m%d-%H%M%S)"


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


install_organizr() {
    if [ -d "${CONFIG_DIR}" ]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config already present at -${STOP_COLOR} '${CONFIG_DIR}'"
        echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!"
        exit 1
    fi

    echo -e "${MAGENTA}${BOLD}[STAGE-1] Adding Organizr config${STOP_COLOR}"
    git clone https://github.com/causefx/Organizr.git ${CONFIG_DIR} >/dev/null 2>&1

    if [[ -d "${CONFIG_DIR}" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config located at${STOP_COLOR} '${CONFIG_DIR}'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to download ${APPNAME} config at${STOP_COLOR} '${CONFIG_DIR}'${RED}${BOLD}. Terminating the script ... Bye!"
        exit 1
    fi

    echo -e "${MAGENTA}${BOLD}[STAGE-2] Adding Nginx Reverse Proxy${STOP_COLOR}"

#install nginx conf
echo 'location /organizr/api/v2 {
  try_files $uri /organizr/api/v2/index.php$is_args$args;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-Proto https;
  proxy_redirect off;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $http_connection;
}' > "$HOME/.apps/nginx/proxy.d/organizr.conf"

    if [[ -f "${HOME}/.apps/nginx/proxy.d/organizr.conf" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} reverse-proxy file created at ${STOP_COLOR}'${HOME}/.apps/nginx/proxy.d/organizr.conf'"
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} reverse-proxy file NOT found at ${STOP_COLOR}'${HOME}/.apps/nginx/proxy.d/organizr.conf'${RED}${BOLD}. Terminating the script ... Bye!$(tput sgr0)"
        exit 1
    fi

    app-nginx restart

    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been installed successfully. You should now be able to access Notifiarr at - ${STOP_COLOR}'https://$USER.$HOSTNAME.usbx.me/organizr'"
    echo -e "  [+] Use your HTTP Access credentials for ${APPNAME}"
}


uninstall_organizr() {
    rm -rf "${CONFIG_DIR}"
    rm "${HOME}/.apps/nginx/proxy.d/organizr.conf"
    app-nginx restart

    if [[ -d "${CONFIG_DIR}" ]] || [[ -f "${HOME}/.apps/nginx/proxy.d/organizr.conf" ]]; then
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

