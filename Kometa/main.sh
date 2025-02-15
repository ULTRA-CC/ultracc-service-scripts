#!/bin/bash

APPNAME="Kometa"
VERSION="2024-07-16"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/scripts/kometa"
CONFIG_FILE="${CONFIG_DIR}/config/config.yml"
CONFIG_TEMPLATE_FILE="${CONFIG_DIR}/config/config.yml.template"
PLEX_PREFS_FILE="${HOME}/.config/plex/Library/Application Support/Plex Media Server/Preferences.xml"
TMPDIR_LOCATION="$HOME/.tmp/kometa-$(date +%Y%m%d-%H%M%S)"

print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}

check_python_version() {
  python_path=$(command -v python)
  echo -e "${YELLOW}${BOLD}[INFO] Python path available on ${HOME} to use:${STOP_COLOR} '${python_path}'"

  INSTALLED_PYTHON_VERSION=$(${python_path} --version 2>&1)

  if [[ ${INSTALLED_PYTHON_VERSION} =~ [Pp]ython\ ([0-9]+\.[0-9]+) ]]; then
    installed_version="${BASH_REMATCH[1]}"
  else
    echo "Error: Unable to determine Python version."
    echo -e "${RED}${BOLD}[ERROR] Failed to determine Python version available on ${HOME}. Terminating the script ... Bye!"
    exit 1
  fi

  IFS='.' read -ra version_parts <<<"$installed_version"
  major_version="${version_parts[0]}"
  minor_version="${version_parts[1]}"

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

get_tmdb_api_key() {
    retries=3
    while (( retries > 0 )); do
        read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your TMDB API key:${STOP_COLOR} " SELECTED_TMDB_API_KEY
        if [ ! -z "$SELECTED_TMDB_API_KEY" ]; then
            break
        else
            echo -e "${RED}${BOLD}[ERROR] API Key can't be empty. You have $retries attempts left.${STOP_COLOR}"
            retries=$((retries - 1))
            if (( retries == 0 )); then
                echo -e "\n${RED}${BOLD}[ERROR] Maximum attempts reached. Terminating the script ... Bye!${STOP_COLOR}"
                exit 1
            fi
        fi
    done
}

install_kometa() {
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
    git clone https://github.com/Kometa-Team/Kometa.git "${CONFIG_DIR}" >/dev/null 2>&1

    if [[ -f "${CONFIG_TEMPLATE_FILE}" ]]; then
        mv "${CONFIG_TEMPLATE_FILE}" "${CONFIG_FILE}"
        echo -e "${YELLOW}${BOLD}[INFO] Renamed config template to:${STOP_COLOR} '${CONFIG_FILE}'"
    else
        echo -e "${RED}${BOLD}[ERROR] Failed to download ${APPNAME} config template at:${STOP_COLOR} '${CONFIG_TEMPLATE_FILE}'"
        exit 1
    fi

    check_python_version
    get_plex_direct_url

    PLEX_TOKEN=$(grep -oP 'PlexOnlineToken="\K[^"]+' "$PLEX_PREFS_FILE")
    echo -e "\n${YELLOW}${BOLD}[INFO] Plex Token:${STOP_COLOR} '${PLEX_TOKEN}'"

    get_tmdb_api_key

    INSTALLED_PYTHON_PATH=$(command -v python)

    cat <<EOF >"$CONFIG_FILE"
plex:
  url: "${PLEX_DIRECT_URL}"
  token: "${PLEX_TOKEN}"
  timeout: 60
  db_cache:
  clean_bundles: false
  empty_trash: false
  optimize: false
tmdb:
  apikey: "${SELECTED_TMDB_API_KEY}"
  language: en
EOF

    echo -e "\n${YELLOW}${BOLD}[INFO] ${APPNAME} config file created at:${STOP_COLOR} '$CONFIG_FILE'"

    (cd ${CONFIG_DIR} && pip install -r requirements.txt) >/dev/null 2>&1

    echo -e "${MAGENTA}${BOLD}[STAGE-2] Create systemd for ${APPNAME}${STOP_COLOR}"
    local service_file="$HOME/.config/systemd/user/kometa.service"

    cat <<EOF >"$service_file"
[Unit]
Description=Kometa
After=multi-user.target

[Service]
Type=simple
Restart=always
RestartSec=3
ExecStart=${INSTALLED_PYTHON_PATH} %h/scripts/${APPNAME}/main.py -c %h/scripts/${APPNAME}/config/config.yml
StandardOutput=file:%h/scripts/${APPNAME}/kometa.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl --user enable kometa.service >/dev/null 2>&1
    systemctl --user start kometa.service

    echo -e "${YELLOW}[INFO] Created systemd file for ${APPNAME}:${STOP_COLOR} '${service_file}'"
    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} installation completed! Check the logs at:${STOP_COLOR} '${HOME}/scripts/${APPNAME}/kometa.log'"
}

uninstall_kometa() {
    systemctl --user stop kometa.service
    systemctl --user disable kometa.service >/dev/null 2>&1

    SERVICE_FILE="$HOME/.config/systemd/user/kometa.service"
    rm -f "${SERVICE_FILE}"
    rm -rf "${CONFIG_DIR}"

    systemctl --user daemon-reload

    if [[ -f ${SERVICE_FILE} ]] || [[ -d "${CONFIG_DIR}" ]]; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} could not be fully uninstalled."
    else
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been uninstalled completely."
    fi
}

update_TMDB_API_key() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} config file can't be found. Terminating the script ... Bye!"
        exit 1
    fi

    get_tmdb_api_key

    sed -i "s/apikey: \".*\"/apikey: \"${SELECTED_TMDB_API_KEY}\"/" "$CONFIG_FILE"
    echo -e "${GREEN}[INFO] TMDB API key has been updated in $CONFIG_FILE.${STOP_COLOR}"
}

main_fn() {
    clear
    print_welcome_message
    echo -e "${YELLOW}${BOLD}[WARNING] Disclaimer: This is an unofficial script and is not supported by Ultra.cc staff. Please proceed only if you understand and accept this.${STOP_COLOR}\n"

    echo -e "${YELLOW}${BOLD}Actions Available: [1] Install ${APPNAME}, [2] Uninstall ${APPNAME}, [3] Update TMDB API key${STOP_COLOR}\n"

    read -rp "${MAGENTA}${BOLD}[INPUT REQUIRED] Select an action [1, 2, or 3]:${STOP_COLOR} " SELECTED_ACTION

    case "$SELECTED_ACTION" in
    1)
        install_kometa
        ;;
    2)
        uninstall_kometa
        ;;
    3)
        update_TMDB_API_key
        ;;
    *)
        echo -e "${RED}${BOLD}[ERROR] Invalid input provided. Terminating the script ... Bye!"
        exit 1
        ;;
    esac
}

main_fn
