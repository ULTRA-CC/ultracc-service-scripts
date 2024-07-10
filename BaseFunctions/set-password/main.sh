#!/bin/bash

BOLD=$(tput bold)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
STOP_COLOR=$(tput sgr0)

set_password(){

#    local CHOSEN_PASSWORD CONFIRM_PASSWORD

    while true; do
        retries=3
        while (( retries > 0 )); do
            read -s -rp "${BLUE}${BOLD}[INPUT REQUIRED] Enter your desired password (minimum 9 characters): ${STOP_COLOR}" CHOSEN_PASSWORD
            echo

            if [ ${#CHOSEN_PASSWORD} -ge 9 ]; then
                break 2
            else
                retries=$((retries - 1))
                echo "${RED}${BOLD}[ERROR] Password must be at least 9 characters long. You have $retries attempts left.${STOP_COLOR}"
                if (( retries == 0 )); then
                    echo -e "\n$(tput setaf 1)$(tput bold)[ERROR] Maximum attempts reached. Terminating the script ... Bye!$(tput sgr0)"
                    exit 1
                fi
            fi
        done
    done

    while true; do
        retries=3
        while (( retries > 0 )); do
            read -s -rp "${BLUE}${BOLD}[INPUT REQUIRED] Confirm your entered password: ${STOP_COLOR}" CONFIRM_PASSWORD
            echo

            if [ "$CHOSEN_PASSWORD" = "$CONFIRM_PASSWORD" ]; then
                break 2
            else
                retries=$((retries - 1))
                echo "${RED}${BOLD}[ERROR] Password do not match! You have $retries attempts left.${STOP_COLOR}"
                if (( retries == 0 )); then
                    echo -e "\n$(tput setaf 1)$(tput bold)[ERROR] Maximum attempts reached. Terminating the script ... Bye!$(tput sgr0)"
                    exit 1
                fi
            fi
        done
    done

}


#run
set_password
