#!/bin/bash


APPNAME="Plex-Auto-Language"
VERSION="2024-07-15"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/scripts/Plex-Auto-Language"
CONFIG_FILE="${CONFIG_DIR}/config/default.yaml"
PLEX_PREFS_FILE="${HOME}/.config/plex/Library/Application Support/Plex Media Server/Preferences.xml"
TMPDIR_LOCATION="$HOME/.tmp/plex_auto_language-$(date +%Y%m%d-%H%M%S)"


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}



check_python_version() {
  python_path=$(command -v python3)
  echo -e "${YELLOW}${BOLD}[INFO] Python path available on ${HOME} to use:${STOP_COLOR} '${python_path}'"

  INSTALLED_PYTHON_VERSION=$(${python_path} --version 2>&1)
  if [[ ${INSTALLED_PYTHON_VERSION} =~ Python\ ([0-9]+\.[0-9]+) ]]; then
    installed_version="${BASH_REMATCH[1]}"
  else
    echo "Error: Unable to determine Python version."
    echo -e "${RED}${BOLD}[ERROR] Failed to determine Python version available on ${HOME}. Terminating the script ... Bye!"
    exit 1
  fi

  IFS='.' read -ra version_parts <<<"$installed_version"
  major_version="${version_parts[0]}"
  minor_version="${version_parts[1]}"

  # Compare the major and minor version numbers
  if [[ "$major_version" -lt 3 || ("$major_version" -eq 3 && "$minor_version" -lt 8) ]]; then
    echo -e "${YELLOW}${BOLD}[INFO] Python 3.8+ required to install ${APPNAME}.${STOP_COLOR}"
    echo -e "${YELLOW}${BOLD}[INFO] Please install Python 3.8 or higher version using the following guide:${STOP_COLOR} 'https://docs.ultra.cc/books/pyenv/page/how-to-install-python-using-pyenv'${STOP_COLOR}"
    echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!"
    exit 1
  else
    echo "${YELLOW}${BOLD}[INFO] Installed Python version on ${HOME}:${STOP_COLOR} '${INSTALLED_PYTHON_VERSION}'"
  fi
}


get_plex_direct_url() {
  local uuid=$(grep -o 'CertificateUUID="[a-zA-Z0-9]*"' "$PLEX_PREFS_FILE" | grep -o '".*"' | sed 's/"//g')
  local ip=$(dig +short "${HOSTNAME}-direct.usbx.me" | sed 's/\./-/g')
  local plexport="$(app-ports show | grep "Plex Media Server" | awk '{print $1}')"
  local url="https://${ip}.${uuid}.plex.direct:${plexport}"

  PLEX_DIRECT_URL="${url}"
  echo -e "\n${YELLOW}${BOLD}[INFO] Plex Direct URL:${STOP_COLOR} '${PLEX_DIRECT_URL}'"
}



install_plex-auto-language() {
    if [ -d "${CONFIG_DIR}" ]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config already present at -${STOP_COLOR} '${CONFIG_DIR}'"
        echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!"
        exit 1
    elif [ ! -f "$PLEX_PREFS_FILE" ]; then
        echo -e "${YELLOW}${BOLD}[INFO] Plex Preferences.xml file NOT found; ensure you have installed Plex Media Server before running this script.${STOP_COLOR}"
        echo -e "${RED}${BOLD}[ERROR] Terminating the script ... Bye!"
        exit 1
    fi

    echo -e "${MAGENTA}${BOLD}[STAGE-1] Download ${APPNAME} config and configure${STOP_COLOR}"
    mkdir -p "${CONFIG_DIR}"
    git clone https://github.com/RemiRigal/Plex-Auto-Languages.git "${CONFIG_DIR}" >/dev/null 2>&1

    if [[ -f "${CONFIG_FILE}" ]]; then
        echo -e "${YELLOW}${BOLD}[INFO] ${APPNAME} config located at${STOP_COLOR} '${CONFIG_DIR}/config'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to download ${APPNAME} config file at${STOP_COLOR} '${CONFIG_DIR}/config'${RED}${BOLD}. Terminating the script ... Bye!"
        exit 1
    fi

    # Check Python version
    check_python_version

    get_plex_direct_url

    PLEX_TOKEN=$(grep -oP 'PlexOnlineToken="\K[^"]+' "$PLEX_PREFS_FILE")
    echo -e "\n${YELLOW}${BOLD}[INFO] Plex Token:${STOP_COLOR} '${PLEX_TOKEN}'"


    INSTALLED_PYTHON_PATH=$(command -v python)


    # Write the content to the config file
    cat <<EOF >"$CONFIG_FILE"
plexautolanguages:
  update_level: "show"
  update_strategy: "all"
  trigger_on_play: true
  trigger_on_scan: true
  trigger_on_activity: false
  refresh_library_on_scan: true
  plex:
    url: "${PLEX_DIRECT_URL}"
    token: "${PLEX_TOKEN}"
  scheduler:
    enable: true
    schedule_time: "04:30"
  notifications:
    enable: false
    apprise_configs: []
  debug: false
EOF

    echo -e "\n${YELLOW}${BOLD}[INFO] ${APPNAME} config file created at:${STOP_COLOR} '$CONFIG_FILE'"

    # pip install requirements
    (cd ${CONFIG_DIR} && pip install -r requirements.txt) >/dev/null 2>&1

    echo -e "${MAGENTA}${BOLD}[STAGE-2] Create systemd for ${APPNAME}${STOP_COLOR}"
    # Create systemd user service file
    local service_file="$HOME/.config/systemd/user/plexautolanguage.service"

    cat <<EOF >"$service_file"
[Unit]
Description=Plex Auto Language
After=multi-user.target

[Service]
Type=simple
Restart=always
RestartSec=3
ExecStart=${INSTALLED_PYTHON_PATH} %h/scripts/${APPNAME}/main.py -c %h/scripts/${APPNAME}/config/config.yaml
StandardOutput=file:%h/scripts/${APPNAME}/plex-auto-language.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl --user enable plexautolanguage.service >/dev/null 2>&1
    systemctl --user start plexautolanguage.service

    echo -e "${YELLOW}[INFO] Created systemd file for ${APPNAME}:${STOP_COLOR} '${service_file}'"
    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} installation completed! Check the logs at:${STOP_COLOR} '${HOME}/scripts/${APPNAME}/plex-auto-language.log'"
}


uninstall_plex-auto-language() {
    systemctl --user stop plexautolanguage.service
    systemctl --user disable plexautolanguage.service  >/dev/null 2>&1

    SERVICE_FILE="$HOME/.config/systemd/user/plexautolanguage.service"
    rm -f "${SERVICE_FILE}"
    rm -rf "${CONFIG_DIR}"

    systemctl --user daemon-reload

    if [[ -f ${SERVICE_FILE} ]] || [[ -d "${CONFIG_DIR}" ]]; then
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
