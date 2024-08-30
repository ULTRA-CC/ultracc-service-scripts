#!/bin/bash

APPNAME="Filebot"
VERSION="2024-07-14"

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
STOP_COLOR=$(tput sgr0)

#CONFIG_DIR="$HOME/.apps/autoscan"
TMPDIR_LOCATION="$HOME/.tmp/autoscan-$(date +%Y%m%d-%H%M%S)"


print_welcome_message() {
    term_width=$(tput cols)
    welcome_message="[[ Welcome to the unofficial ${APPNAME} script ]]"
    padding=$(printf '%*s' $(((term_width-${#welcome_message}) / 2)) '')
    echo -e "\n${CYAN}${BOLD}${padding}${welcome_message}${STOP_COLOR}\n"
}


install_filebot() {
    echo -e "\n${BLUE}${BOLD}[LIST] ${APPNAME} versions available for installation:${STOP_COLOR}"
    echo "1) 5.1.5"
    echo "2) 5.0.1"
    echo "3) 5.0.0"
    echo "4) 4.9.4"
    echo -e "5) 4.9.3\n"

    while true; do
        read -r -p "${BLUE}${BOLD}[INPUT REQUIRED] Enter your version choice${STOP_COLOR} '[1-4]'${BLUE}${BOLD}: ${STOP_COLOR} " SELECTED_VERSION
        case ${SELECTED_VERSION} in
            1)
                version=5.1.5
                break
                ;;
            2)
                version=5.0.1
                break
                ;;
            3)
                version=5.0.0
                break
                ;;

            4)
                version=4.9.4
                break
                ;;
            5)
                version=4.9.3
                break
                ;;
            *)
                echo -e "${RED}{BOLD}[ERROR] Invalid choice. Please enter a number between 1 and 4.${STOP_COLOR}"
                exit 1
                ;;
        esac
    done

    echo -e "\n${MAGENTA}${BOLD}[STAGE-1] Downloading ${APPNAME} binary and configuration ${STOP_COLOR}"

    PACKAGE_VERSION=$version
    PACKAGE_SHA256=$(curl -fsSL https://raw.githubusercontent.com/filebot/website/master/get.filebot.net/filebot/FileBot_$PACKAGE_VERSION/FileBot_$PACKAGE_VERSION-portable.tar.xz.sha256)
    PACKAGE_FILE=FileBot_$PACKAGE_VERSION-portable.tar.xz
    PACKAGE_URL=https://get.filebot.net/filebot/FileBot_$PACKAGE_VERSION/$PACKAGE_FILE

    # Create directory for all FileBot data and change working directory
    mkdir -p "$HOME"/.filebot-$PACKAGE_VERSION && cd "$HOME"/.filebot-$PACKAGE_VERSION || exit

    # Fetch OpenJDK 15 binaries archive
    curl -o Java15.tar.gz "https://download.java.net/java/GA/jdk15.0.1/51f4f36ad4ef43e39d0dfdbaf6549e32/9/GPL/openjdk-15.0.1_linux-x64_bin.tar.gz" >/dev/null 2>&1

    # Extract OpenJDK 15 binaries and remove archives
    tar xf Java15.tar.gz
    rm Java15.tar.gz

    # Download FileBot package
    curl -o "$PACKAGE_FILE" -z "$PACKAGE_FILE" "$PACKAGE_URL" >/dev/null 2>&1

    # Check SHA-256 checksum
    SHA256_CHECKSUM=$(echo "$PACKAGE_SHA256 *$PACKAGE_FILE" | sha256sum --check || exit 1)
    echo -e "\n${YELLOW}${BOLD}[INFO] SHA-256 Checksum: ${SHA256_CHECKSUM} ${STOP_COLOR}"

    # Extract FileBot archive
    tar xf "$PACKAGE_FILE"

    # Clean up FileBot files
    rm "$PACKAGE_FILE" reinstall-filebot.sh update-filebot.sh

    # Increase maximum amount of memory that can be allocated to the JVM heap
    sed -i '/#!\/bin\/sh/a export JAVA_OPTS=\"-Xms128m -Xmx384m -XX:CompressedClassSpaceSize=256m -XX:MaxMetaspaceSize=256m -XX:NativeMemoryTracking=summary -XX:MaxRAM=2g -XX:MaxRAMPercentage=70 -XX:ActiveProcessorCount=4\"' filebot.sh

    # Use custom OpenJDK 15 installation to run FileBot
    sed -i '/^java/ s#java#'"$PWD"'\/jdk-15.0.1\/bin\/java#' filebot.sh

    echo -e "\n${MAGENTA}${BOLD}[STAGE-2] Check ${APPNAME} binary${STOP_COLOR}"

    # Check if filebot.sh works
    if [[ -f "$PWD/filebot.sh" ]]; then
        echo -e "\n${YELLOW}${BOLD}[INFO] Check if filebot.sh is working or not ...${STOP_COLOR}"
        "$PWD/filebot.sh" -script https://scripts.usbx.me/main-v2/FileBot/usbsysinfo.groovy
    else
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} binary NOT found at ${STOP_COLOR}'$PWD/filebot.sh''${RED}${BOLD}. Terminating the script ... Bye!${STOP_COLOR}"
        exit 1
    fi

    ln -sf "$PWD/filebot.sh" "$HOME"/bin/filebot

    VERSION_CHECK=$(filebot -version)
    echo -e "\n${YELLOW}${BOLD}[INFO] Filebot version:${STOP_COLOR} ${VERSION_CHECK}"
    echo -e "\n${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been installed successfully."
}


uninstall_filebot() {
    if [ -d "$HOME/filebot-493" ];
    then
        rm -rfv $HOME/filebot-493 >> /dev/null 2>&1 && rm "$HOME"/bin/filebot >> /dev/null 2>&1
    else
        rm -rfv "$HOME"/.filebot* >> /dev/null 2>&1 && rm $HOME/bin/filebot >> /dev/null 2>&1
    fi

    if [[ -f ${HOME}/.filebot* ]] || [[ -f ${HOME}/bin/filebot ]]; then
        echo -e "${RED}${BOLD}[ERROR] ${APPNAME} could not be fully uninstalled."
    else
        echo -e "${GREEN}${BOLD}[SUCCESS] ${APPNAME} has been uninstalled completely."
    fi
}


upgrade_filebot() {
    echo -e "\n${MAGENTA}${BOLD}[STAGE-1] Uninstalling existing ${APPNAME} instance${STOP_COLOR}"
    uninstall_filebot
    echo -e "\n${MAGENTA}${BOLD}[STAGE-2] Initalizing ${APPNAME} fresh install${STOP_COLOR}"
    install_filebot
}


activate_filebot_license() {
    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter full path of ${APPNAME} license where it's stored i.e. ${HOME}/FileBot_License_PXXXXXXXX.psm : ${STOP_COLOR}" License
    filebot --license $License
}


install_amc_script() {
    if [ ! -d "$HOME/scripts/amc" ]; then
        mkdir -p ~/scripts/amc
    fi
    echo -e "${BLUE}${BOLD}[LIST] AMC script available for following applications:${STOP_COLOR}"
    echo "1) rTorrent"
    echo "2) Deluge"
    echo -e "3) Transmission\n"
    while true; do
        read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Choose your application for AMC script${STOP_COLOR} '[1-3]'${BLUE}${BOLD}:${STOP_COLOR} " amc_appname
        case $amc_appname in
            1)
                app-rtorrent stop
                wget -P ~/scripts/amc https://scripts.usbx.me/main-v2/FileBot/AMC/rtorrent-amc.sh >/dev/null 2>&1 && chmod +rx ~/scripts/amc/rtorrent-amc.sh
                sed -i '/method.set_key = event.download.finished,filebot/d' ~/.config/rtorrent/rtorrent.rc
                echo 'method.set_key = event.download.finished,filebot,"execute.nothrow=~/scripts/amc/rtorrent-amc.sh,$d.base_path=,$d.name=,$d.custom1="' >> ~/.config/rtorrent/rtorrent.rc
                app-rtorrent restart
                echo -e "${GREEN}${BOLD}[SUCCESS] AMC script for rTorrent has been installed successfully at :${STOP_COLOR} ${HOME}/scripts/amc/rtorrent-amc.sh"
                break
            ;;
            2)
                wget -P ~/scripts/amc https://scripts.usbx.me/main-v2/FileBot/AMC/deluge-amc.sh >/dev/null 2>&1 && chmod +rx ~/scripts/amc/deluge-amc.sh
                echo "${YELLOW}${BOLD}[INFO] Copy the last line in Deluge:${STOP_COLOR} go to Preferences -> Execute. Set the following: Event: Torrent Complete -> Command: ${HOME}/amc/scripts/deluge-amc.sh"
                echo "${YELLOW}${BOLD}[INFO] Restart your Deluge app from UCP or execute command `app-deluge restart` from shell.${STOP_COLOR}"
                echo -e "\n${GREEN}${BOLD}[SUCCESS] AMC script for Deluge has been installed successfully at :${STOP_COLOR} ${HOME}/scripts/amc/deluge-amc.sh"
                break
            ;;
            3)
                app-transmission stop
                wget -P ~/scripts/amc https://scripts.usbx.me/main-v2/FileBot/AMC/transmission-amc.sh >/dev/null 2>&1 && chmod +rx ~/scripts/amc/transmission-amc.sh
                sed -i 's#^    "script-torrent-done-enabled".*#    "script-torrent-done-enabled": true,#' "$HOME"/.config/transmission-daemon/settings.json
                sed -i 's#^    "script-torrent-done-filename".*#    "script-torrent-done-filename": "'"$HOME"'/scripts/amc/transmission-amc.sh",#' "$HOME"/.config/transmission-daemon/settings.json app-transmission restart
                echo -e "${GREEN}${BOLD}[SUCCESS] AMC script for rTorrent has been installed successfully at :${STOP_COLOR} ${HOME}/scripts/amc/transmission-amc.sh"
                break
            ;;

            *)
                echo "Invalid Option. Try again..."
            ;;
        esac
    done
}


main_fn() {
    clear
    print_welcome_message
    echo -e "${YELLOW}${BOLD}[WARNING] Disclaimer: This is an unofficial script and is not supported by Ultra.cc staff. Please proceed only if you are experienced with managing such custom installs on your own.${STOP_COLOR}\n"

    echo -e "${BLUE}${BOLD}[LIST] Operations available for ${APPNAME}:${STOP_COLOR}"
    echo "1) Install"
    echo "2) Uninstall"
    echo "3) Upgrade"
    echo "4) Activate License"
    echo -e "5) Install AMC script\n"

    read -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your operation choice${STOP_COLOR} '[1-5]'${BLUE}${BOLD}: ${STOP_COLOR}" OPERATION_CHOICE
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
        4)
            activate_${APPNAME,,}_license
            ;;
        5)
            install_amc_script
            ;;
        *)
            echo -e "${RED}${BOLD}[ERROR] Invalid choice. Please enter a number between 1 and 5.${STOP_COLOR}"
            exit 1
            ;;
    esac
}


# Call the main function
main_fn
