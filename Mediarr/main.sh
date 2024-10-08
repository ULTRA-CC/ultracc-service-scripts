#!/bin/bash

set -euo pipefail

APPNAME="Mediarr"
VERSION="2024-07-16"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

TMPDIR_LOCATION="$HOME/.tmp/mediarr-$(date +%Y%m%d-%H%M%S)"
PYTHON_PATH=$(which python3)

print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


main_fn() {
    clear
    print_welcome_message
    echo -e "${YELLOW}${BOLD}[WARNING] Disclaimer: This is an unofficial script and is not supported by Ultra.cc staff. Please proceed only if you are experienced with managing such custom installs on your own.${STOP_COLOR}\n"

    echo -e "${BLUE}${BOLD}[LIST] Operations available for ${APPNAME}:${STOP_COLOR}"
    echo "1) Lidarr"
    echo "2) Prowlarr"
    echo -e "3) Readarr\n"

    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your operation choice${STOP_COLOR} '[1-3]'${BLUE}${BOLD}: ${STOP_COLOR}" OPERATION_CHOICE
    echo

    # Check user choice and execute function
    case "$OPERATION_CHOICE" in
        1)
            branch="master"
            app="lidarr"
            ;;
        2)
            branch="develop"
            app="prowlarr"
            ;;
        3)
            branch="develop"
            app="readarr"
            ;;
        *)
            echo -e "${RED}{BOLD}[ERROR] Invalid choice. Please enter a number between 1 and 3.${STOP_COLOR}"
            exit 1
            ;;
    esac
}

# Call the main function
main_fn


#Functions

port_picker() {
  mkdir -p ${TMPDIR_LOCATION}
  wget -qO ${TMPDIR_LOCATION}/port-selector.sh https://scripts.usbx.me/main-v2/BaseFunctions/port-selector/main.sh
  source ${TMPDIR_LOCATION}/port-selector.sh
  port=${SELECTED_PORT}

  rm -rf ${TMPDIR_LOCATION}
}


required_paths() {
  declare -a paths
  paths[1]="${HOME}/.apps/${app}2"
  paths[2]="${HOME}/.config/systemd/user"
  paths[3]="${HOME}/.apps/nginx/proxy.d"
  paths[4]="${HOME}/bin"
  paths[5]="${HOME}/.apps/backup"
  paths[6]="${HOME}/.tmp"

  for i in {1..6}; do
    if [ ! -d "${paths[${i}]}" ]; then
      mkdir -p "${paths[${i}]}"
    fi
  done
}


get_password() {
  mkdir -p ${TMPDIR_LOCATION}
  wget -qO ${TMPDIR_LOCATION}/set-password.sh https://scripts.usbx.me/main-v2/BaseFunctions/set-password/main.sh
  source ${TMPDIR_LOCATION}/set-password.sh
  password=${CHOSEN_PASSWORD}

  rm -rf ${TMPDIR_LOCATION}
}


get_binaries() {
  rm -rf "${HOME}/.config/${app}2"
  echo
  echo -e "${YELLOW}${BOLD}[INFO] Pulling new binaries..${STOP_COLOR}"
  mkdir -p "${HOME}"/.config/.temp
  wget -qO "${HOME}"/.config/.temp/${app}.tar.gz --content-disposition "http://${app}.servarr.com/v1/update/${branch}/updatefile?os=linux&runtime=netcore&arch=x64"
  tar -xzf "${HOME}"/.config/.temp/${app}.tar.gz -C "${HOME}/.config/.temp" && mv "${HOME}/.config/.temp/${app^}" "${HOME}/.config/${app}2" && rm -rf "${HOME}"/.config/.temp

  if [[ -d "${HOME}/.config/${app}2" ]]; then
      echo -e "${YELLOW}${BOLD}[INFO] ${app}2 binaries stored at ${STOP_COLOR}'${HOME}/.config/${app}2'"
  else
      echo -e "${RED}${BOLD}[ERROR] ${app}2 binaries NOT found at ${STOP_COLOR}'${HOME}/.config/${app}2''${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
      exit 1
  fi
}

nginx_conf_install() {
  cat <<EOF | tee "${HOME}/.apps/nginx/proxy.d/${app}2.conf" >/dev/null
location /${app}2 {
  proxy_pass        http://127.0.0.1:${port}/${app}2;
  proxy_set_header Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-Proto https;
  proxy_redirect off;

  proxy_http_version 1.1;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection \$http_connection;
}
  location /${app}2/api { auth_request off;
  proxy_pass       http://127.0.0.1:${port}/${app}2/api;
}

  location /${app}2/Content { auth_request off;
    proxy_pass http://127.0.0.1:${port}/${app}2/Content;
}
EOF

  if [[ -f "${HOME}/.apps/nginx/proxy.d/${app}2.conf" ]]; then
      echo -e "${YELLOW}${BOLD}[INFO] ${app}2 reverse-proxy file created at ${STOP_COLOR}'${HOME}/.apps/nginx/proxy.d/${app}2.conf'"
      app-nginx restart
  else
      echo -e "${RED}${BOLD}[ERROR] ${app}2 reverse-proxy file NOT found at ${STOP_COLOR}'${HOME}/.apps/nginx/proxy.d/${app}2.conf'${RED}${BOLD}. Terminating the script ... Bye!$(tput sgr0)"
      exit 1
  fi
}


systemd_service_install() {
  cat <<EOF | tee "${HOME}"/.config/systemd/user/${app}.service >/dev/null
[Unit]
Description=${app^} Daemon
After=network-online.target
[Service]
Environment="TMPDIR=%h/.tmp"
PrivateTmp=true
Type=simple

ExecStart=%h/.config/${app}2/${app^} -nobrowser -data=%h/.apps/${app}2/
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload

  if [[ -f "${HOME}/.config/systemd/user/${app}.service" ]]; then
      echo -e "${YELLOW}${BOLD}[INFO] ${app}2 systemd file created at ${STOP_COLOR}'${HOME}/.config/systemd/user/${app}.service'"
  else
      echo -e "${RED}${BOLD}[ERROR] ${app}2 systemd file NOT found at ${STOP_COLOR}'${HOME}/.config/systemd/user/${app}.service'${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
      exit 1
  fi
}

create_arr_config() {
  cat <<EOF | tee "${HOME}/.apps/${app}2/config.xml" >/dev/null
<Config>
  <LogLevel>info</LogLevel>
  <UrlBase>/${app}2</UrlBase>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <Branch>${branch}</Branch>
  <Port>${port}</Port>
  <AuthenticationMethod>Forms</AuthenticationMethod>
  <BindAddress>127.0.0.1</BindAddress>
</Config>
EOF
  echo -e "${YELLOW}${BOLD}[INFO] ${app}2 config stored at ${STOP_COLOR}'${HOME}/.apps/${app}2'"
}


update_arr_config() {
  if [ ! -f "${HOME}/.apps/${app}2/config.xml" ] || [ -z "$(cat "${HOME}/.apps/${app}2/config.xml")" ]; then
    echo
    echo -e "${RED}${BOLD}[ERROR] ${app^}2's config.xml does not exist or is empty.${STOP_COLOR}"
    echo "Do you wish to create a fresh new config.xml?"
    echo
    select yn in "Yes" "No"; do
      case $yn in
      Yes)
        create_arr_config && echo "${YELLOW}${BOLD}[INFO] New config.xml created.${STOP_COLOR}"
        break
        ;;
      No) echo "${RED}${BOLD}[ERROR] Update & Repair failed. Terminating the script ... Bye!${STOP_COLOR}" && exit 1 ;;
      esac
    done
  fi

  sed -i "s+<Port>.*</Port>+<Port>${port}</Port>+g" "${HOME}/.apps/${app}2/config.xml"
  sed -i "s+<UrlBase>.*</UrlBase>+<UrlBase>/${app}2</UrlBase>+g" "${HOME}/.apps/${app}2/config.xml"
  sed -i "s+<BindAddress>.*</BindAddress>+<BindAddress>127.0.0.1</BindAddress>+g" "${HOME}/.apps/${app}2/config.xml"

  echo -e "${YELLOW}${BOLD}[INFO] ${app}2 config stored at ${STOP_COLOR}'${HOME}/.apps/${app}2'"
}


create_arr_user() {

  if ! systemctl --user is-active --quiet "${app}.service"; then
    echo "${RED}${BOLD}[ERROR] Initial instance of ${app^} failed to start properly, install aborted. Please check port selection, HDD IO and other resource utilization.${STOP_COLOR}"
    echo "${YELLOW}${BOLD}[INFO]Then run the script again and choose Fresh Install."
    exit 1
  fi

  count=1
  while systemctl --user is-active --quiet "${app}.service" && [ ! -f "${HOME}/.apps/${app}2/${app}.db" ] && ${count} -le 6; do
    if [ ${count} -ge 6 ]; then
      echo "${RED}${BOLD}[ERROR] Failed to create sqlite database, install aborted. Please check port selection, HDD IO and other resource utilization.${STOP_COLOR}"
      echo "${YELLOW}${BOLD}[INFO] Then run the script again and choose Fresh Install."
      exit 1
    fi
    sleep 5
    count=$(("${count}" + 1))
  done

  if ! sqlite3 "${HOME}/.apps/${app}2/${app}.db" ".tables" | grep -q "Users"; then
    echo "${RED}${BOLD}[ERROR] Initial ${app}.db is corrupted. Install aborted. Please check HDD IO and other resource utilization.${STOP_COLOR}"
    echo "${YELLOW}${BOLD}[INFO] Then run the script again and choose Fresh Install."
    exit 1
  fi
  #echo -n "done."

  systemctl --user stop "${app}.service"

  username=${USER}
  guid=$(cat /proc/sys/kernel/random/uuid)
  password_hash=$(echo -n "${password}" | sha256sum | awk '{print $1}')

  sqlite3 "${HOME}/.apps/${app}2/${app}.db" <<EOF
INSERT INTO Users (Id, Identifier, Username, Password)
VALUES ( 1, "$guid", "$username", "$password_hash");
EOF

  systemctl --user restart "${app}.service"

}


update_arr_user() {
  password_hash=$(echo -n "${password}" | sha256sum | awk '{print $1}')
  sqlite3 "${HOME}/.apps/${app}2/${app}.db" <<EOF
UPDATE Users
SET Password = "$password_hash";
EOF
}


create_backup() {
  backup="${HOME}/.apps/backup/${app}2-$(date +%Y-%m-%d_%H-%M-%S).bak.tar.gz"
  echo
  tar -czf "${backup}" -C "${HOME}/.apps/" "${app}2"
  echo -e "${YELLOW}${BOLD}[INFO] Backup created of ${app}2:${STOP_COLOR} '${backup}'"
}


uninstall() {
  echo
  echo "Uninstalling second instance of ${app^}.."
  [ -f "${HOME}/.config/systemd/user/${app}.service" ] && systemctl --user --force stop "${app}.service"
  [ -f "${HOME}/.config/systemd/user/${app}.service" ] && systemctl --user --force disable "${app}.service" >/dev/null 2>&1
  rm -f "${HOME}/.config/systemd/user/${app}.service"
  systemctl --user daemon-reload
  systemctl --user reset-failed
  rm -rf "${HOME}/.apps/${app}2"
  rm -rf "${HOME}/.config/${app}2"
  rm -f "${HOME}/.apps/nginx/proxy.d/${app}2.conf"
  app-nginx restart
  echo
  echo -e "${GREEN}${BOLD}[SUCCESS] Uninstallation Complete.${STOP_COLOR}"
}


fresh_install() {
  if [ ! -d "${HOME}/.apps/${app}2" ]; then
    echo
    echo -e "${YELLOW}${BOLD}[INFO] Fresh install of ${app^}2.${STOP_COLOR}"
    sleep 3
    #clear
    echo -e "\n${MAGENTA}${BOLD}[STAGE-1] Port selection${STOP_COLOR}"
    port_picker
    echo -e "\n${MAGENTA}${BOLD}[STAGE-2] Configure ${app}2${STOP_COLOR}"
    required_paths
    get_password
    get_binaries
    create_arr_config
    echo -e "\n${MAGENTA}${BOLD}[STAGE-3] Set up ${app}2 Nginx and Systemd${STOP_COLOR}"
    nginx_conf_install
    systemd_service_install
    systemctl --user --quiet enable --now "${app}.service" >/dev/null 2>&1
    echo
    echo
    echo -e "${YELLOW}${BOLD}[INFO] Waiting for initial DB to be created..${STOP_COLOR}"
    sleep 10

    create_arr_user
    if systemctl --user is-active --quiet "${app}.service" && systemctl --user is-active --quiet "nginx.service"; then
      echo
      echo
      echo -e "${GREEN}${BOLD}[SUCCESS] ${app^}2 installation is complete.${STOP_COLOR}"
      echo -e "  [+] Visit the WebUI at the following URL: 'https://${USER}.${HOSTNAME}.usbx.me/${app}2'"
      echo -e "  [+] username: '${USER}' and password: '${password}'"
      if [ -n "${backup}" ]; then echo && echo "Backup of old instance has been saved at ${backup}"; fi
      echo
      exit
    else
      echo "${RED}${BOLD}[ERROR] Something went wrong. Run the script again." && exit 1
    fi
  fi
}


backup=''
fresh_install

if [ -d "${HOME}/.apps/${app}2" ]; then
  echo
  echo -e "${YELLOW}${BOLD}[INFO] Old installation of ${app^}2 detected.${STOP_COLOR}"
  echo -e "\n${BLUE}${BOLD}[LIST] How do you wish to proceed? In all cases except quit, the old AppData directory will be backed up.${STOP_COLOR}"

  PS3="${BLUE}${BOLD}Choose the option between${STOP_COLOR} '[1-5]'${BLUE}${BOLD}: ${STOP_COLOR}"

  select status in 'Fresh Install' 'Update & Repair' 'Change Password' 'Uninstall' 'Quit'; do

    case ${status} in
    'Fresh Install')
      [ -f "${HOME}/.config/systemd/user/${app}.service" ] && systemctl --user stop "${app}.service"
      create_backup
      uninstall
      fresh_install
      break
      ;;
    'Update & Repair')
      systemctl --user stop "${app}.service"
      create_backup
      echo
      #echo "Update and Repair ${app^}2"
      sleep 3
      #clear
      port_picker
      required_paths
      get_binaries
      nginx_conf_install
      systemd_service_install
      update_arr_config
      systemctl --user restart "${app}.service"
      echo
      echo "${GREEN}${BOLD}[SUCCESS] ${app^}2 has been updated & repaired.${STOP_COLOR}"
      echo
      exit
      break
      ;;
    'Change Password')
      systemctl --user stop "${app}.service"
      create_backup
      echo
      get_password
      update_arr_user
      systemctl --user restart "${app}.service"
      echo
      echo "${GREEN}${BOLD}[SUCCESS] ${app^}2's password changed successfully. New Password is${STOP_COLOR} '${password}' "
      echo
      exit
      break
      ;;
    'Uninstall')
      [ -f "${HOME}/.config/systemd/user/${app}.service" ] && systemctl --user --force stop "${app}.service"
      create_backup
      uninstall
      echo
      exit
      break
      ;;
    'Quit')
      exit 0
      ;;
    *)
      echo "Invalid option $REPLY."
      ;;
    esac
  done
fi
