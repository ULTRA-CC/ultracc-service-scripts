#!/bin/bash

APPNAME="Kometa"
APPNAME_LC="kometa" # filesystem + systemd name; APPNAME is display-only
VERSION="2026-07-26"

PYTHON_MIN_MINOR=10 # kometa.py refuses to run below 3.10
PYENV_GUIDE="https://docs.ultra.cc/books/pyenv/page/how-to-install-python-using-pyenv"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

CONFIG_DIR="$HOME/scripts/${APPNAME_LC}"
CONFIG_FILE="${CONFIG_DIR}/config/config.yml"
CONFIG_TEMPLATE_FILE="${CONFIG_DIR}/config/config.yml.template"
PLEX_PREFS_FILE="${HOME}/.config/plex/Library/Application Support/Plex Media Server/Preferences.xml"
SERVICE_FILE="${HOME}/.config/systemd/user/${APPNAME_LC}.service"
LOG_FILE="${CONFIG_DIR}/${APPNAME_LC}.log"

die() {
    echo -e "${RED}${BOLD}[ERROR] $1 Terminating the script ... Bye!${STOP_COLOR}"
    exit 1
}

info() { echo -e "${YELLOW}${BOLD}[INFO] $1${STOP_COLOR} '$2'"; }

print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}

check_python_version() {
  python_path=$(command -v python)
  [[ -n "${python_path}" ]] || die "No 'python' found on PATH. Install Python 3.${PYTHON_MIN_MINOR}+ first: '${PYENV_GUIDE}'."
  info "Python path available on ${HOME} to use:" "${python_path}"

  INSTALLED_PYTHON_VERSION=$(${python_path} --version 2>&1)

  if [[ ${INSTALLED_PYTHON_VERSION} =~ [Pp]ython\ ([0-9]+\.[0-9]+) ]]; then
    installed_version="${BASH_REMATCH[1]}"
  else
    die "Failed to determine Python version available on ${HOME}."
  fi

  IFS='.' read -ra version_parts <<<"$installed_version"
  major_version="${version_parts[0]}"
  minor_version="${version_parts[1]}"

  if [[ "$major_version" -lt 3 || ("$major_version" -eq 3 && "$minor_version" -lt ${PYTHON_MIN_MINOR}) ]]; then
    echo -e "${YELLOW}${BOLD}[INFO] Python 3.${PYTHON_MIN_MINOR}+ required to install ${APPNAME}, found ${installed_version}.${STOP_COLOR}"
    echo -e "${YELLOW}${BOLD}[INFO] Please install Python 3.${PYTHON_MIN_MINOR} or higher version using the following guide:${STOP_COLOR} '${PYENV_GUIDE}'${STOP_COLOR}"
    die "Unsupported Python version."
  else
    info "Installed Python version on ${HOME}:" "${INSTALLED_PYTHON_VERSION}"
  fi
}

get_plex_direct_url() {
  local uuid ip plexport
  uuid=$(grep -o 'CertificateUUID="[a-zA-Z0-9]*"' "$PLEX_PREFS_FILE" | grep -o '".*"' | sed 's/"//g')
  ip=$(dig +short "${HOSTNAME}-direct.usbx.me" | grep -m1 -E '^[0-9.]+$' | sed 's/\./-/g') # -m1: multi-A records
  plexport="$(app-ports show | grep "Plex Media Server" | awk '{print $1}')"

  # an empty part here silently yields an unreachable plex.direct URL, so fail loudly instead
  [[ -n "${uuid}" ]]     || die "No CertificateUUID in Preferences.xml; start Plex once and claim it, then retry."
  [[ -n "${ip}" ]]       || die "'${HOSTNAME}-direct.usbx.me' did not resolve; cannot build the Plex URL."
  [[ -n "${plexport}" ]] || die "No Plex Media Server port from 'app-ports show'; is Plex installed?"

  PLEX_DIRECT_URL="https://${ip}.${uuid}.plex.direct:${plexport}"
  echo -e "\n${YELLOW}${BOLD}[INFO] Plex Direct URL:${STOP_COLOR} '${PLEX_DIRECT_URL}'"
}

get_plex_token() {
    PLEX_TOKEN=$(grep -oP 'PlexOnlineToken="\K[^"]+' "$PLEX_PREFS_FILE")
    [[ -n "${PLEX_TOKEN}" ]] || die "No PlexOnlineToken in Preferences.xml; sign in to Plex once, then retry."
    echo -e "\n${YELLOW}${BOLD}[INFO] Plex Token:${STOP_COLOR} '${PLEX_TOKEN}'"
}

get_tmdb_api_key() {
    retries=3
    while (( retries > 0 )); do
        read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your TMDB API key:${STOP_COLOR} " SELECTED_TMDB_API_KEY
        retries=$((retries - 1))
        if [[ "$SELECTED_TMDB_API_KEY" =~ ^[A-Za-z0-9._-]+$ ]]; then # chars that are safe in YAML and sed
            break
        fi
        echo -e "${RED}${BOLD}[ERROR] API key must be non-empty and alphanumeric. You have $retries attempts left.${STOP_COLOR}"
        if (( retries == 0 )); then
            echo
            die "Maximum attempts reached."
        fi
    done
}

install_kometa() {
    if [ -d "${CONFIG_DIR}" ]; then
        info "${APPNAME} config already present at -" "${CONFIG_DIR}"
        die "Run this script again and choose [2] to uninstall first."
    elif [ ! -f "$PLEX_PREFS_FILE" ]; then
        echo -e "${YELLOW}${BOLD}[INFO] Plex Preferences.xml file NOT found; ensure you have installed Plex Media Server before running this script.${STOP_COLOR}"
        die "Plex Media Server is required."
    fi

    check_python_version # before the clone, so a bad Python fails fast

    echo -e "${MAGENTA}${BOLD}[STAGE-1] Download ${APPNAME} config and configure${STOP_COLOR}"
    mkdir -p "${CONFIG_DIR}"
    if ! git clone https://github.com/Kometa-Team/Kometa.git "${CONFIG_DIR}" >/dev/null 2>&1; then
        rm -rf "${CONFIG_DIR}" # leave no half-clone behind to block the retry
        die "Failed to clone ${APPNAME} from GitHub."
    fi

    if [[ -f "${CONFIG_TEMPLATE_FILE}" ]]; then
        mv "${CONFIG_TEMPLATE_FILE}" "${CONFIG_FILE}"
        info "Renamed config template to:" "${CONFIG_FILE}"
    else
        die "Failed to download ${APPNAME} config template at: '${CONFIG_TEMPLATE_FILE}'."
    fi

    get_plex_direct_url
    get_plex_token
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

    if ! (cd "${CONFIG_DIR}" && pip install -r requirements.txt) >/dev/null 2>&1; then
        die "'pip install -r requirements.txt' failed; ${APPNAME} cannot start without its dependencies."
    fi

    echo -e "${MAGENTA}${BOLD}[STAGE-2] Create systemd for ${APPNAME}${STOP_COLOR}"
    mkdir -p "$(dirname "${SERVICE_FILE}")"

    cat <<EOF >"$SERVICE_FILE"
[Unit]
Description=${APPNAME}
After=network-online.target

[Service]
Type=exec
Restart=always
RestartSec=3
Environment=PYTHONUNBUFFERED=1
ExecStart=${INSTALLED_PYTHON_PATH} %h/scripts/${APPNAME_LC}/kometa.py -c %h/scripts/${APPNAME_LC}/config/config.yml
StandardOutput=append:%h/scripts/${APPNAME_LC}/${APPNAME_LC}.log

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable "${APPNAME_LC}.service" >/dev/null 2>&1
    systemctl --user start "${APPNAME_LC}.service"
    info "Created systemd file for ${APPNAME}:" "${SERVICE_FILE}"

    # a dead unit used to still print [SUCCESS]; verify before claiming it worked
    if ! systemctl --user is-active --quiet "${APPNAME_LC}.service"; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} service failed to start:${STOP_COLOR}"
        systemctl --user status "${APPNAME_LC}.service" --no-pager -l 2>&1 | tail -n 10
        die "${APPNAME} was installed but is not running."
    fi

    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} installation completed! Check the logs at:${STOP_COLOR} '${LOG_FILE}'"
}

uninstall_kometa() {
    systemctl --user stop "${APPNAME_LC}.service" 2>/dev/null
    systemctl --user disable "${APPNAME_LC}.service" >/dev/null 2>&1

    rm -f "${SERVICE_FILE}"
    # pre-fix installs enabled into multi-user.target.wants, which disable no longer sees
    rm -f "${HOME}/.config/systemd/user/multi-user.target.wants/${APPNAME_LC}.service" \
          "${HOME}/.config/systemd/user/default.target.wants/${APPNAME_LC}.service"
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
        die "${APPNAME} config file can't be found."
    fi

    get_tmdb_api_key

    # scoped to the tmdb block so omdb/mdblist apikeys are left alone
    sed -i "/^tmdb:/,/^[^[:space:]#]/ s|^\([[:space:]]*apikey:\).*|\1 \"${SELECTED_TMDB_API_KEY}\"|" "$CONFIG_FILE"
    echo -e "${GREEN}[INFO] TMDB API key has been updated in $CONFIG_FILE.${STOP_COLOR}"
    echo -e "${YELLOW}${BOLD}[INFO] Restart ${APPNAME} to apply:${STOP_COLOR} 'systemctl --user restart ${APPNAME_LC}.service'"
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
        die "Invalid input provided."
        ;;
    esac
}

# Make sure $PATH is up to date
# Fixes the issue of kometa failing to detect ~/.pyenv right after Python install
source "$HOME/.profile"
main_fn
