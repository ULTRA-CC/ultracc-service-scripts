#!/bin/bash

# Function to allow the user to select a port
select_port() {
    while true; do
        echo -e "$(tput setaf 6)$(tput bold)Ports available for custom installs:$(tput sgr0)"
        printf '%0.s-' {1..36} && echo
        /usr/bin/app-ports free | grep -v -E 'Unallocated ports for use|----' | sort -nr | awk '{
            printf "%s ", $1;
            if (NR % 5 == 0) print ""
        }'
        echo

        HIGHEST_PORT=$(/usr/bin/app-ports free | grep -v -E 'Unallocated ports for use|----' | sort -nr | head -n 1)

        echo -e "$(tput setaf 3)[INFO] Please select a port from the above list to use [higher port recommended - e.g. ${HIGHEST_PORT}]"
        echo -e "[INFO] Avoid selecting ports that are already in use for other custom installations.$(tput sgr0)\n"

        retries=3
        while (( retries > 0 )); do
            read -rp "$(tput setaf 4)$(tput bold)[INPUT REQUIRED] Enter the desired port number: $(tput sgr0)" SELECTED_PORT

            if /usr/bin/app-ports free | grep -q "\<${SELECTED_PORT}\>"; then
                break
            else
                retries=$((retries - 1))
                echo -e "$(tput setaf 1)$(tput bold)[ERROR] Entered port is either unavailable or invalid. You have $retries attempts left.$(tput sgr0)"
                if (( retries == 0 )); then
                    echo -e "\n$(tput setaf 1)$(tput bold)[ERROR] Maximum attempts reached. Terminating the script ... Bye!$(tput sgr0)"
                    exit
                fi
            fi
        done

        echo
        read -rp "$(tput setaf 4)$(tput bold)[INPUT REQUIRED] You have selected port $(tput sgr0)'${SELECTED_PORT}'$(tput setaf 4)$(tput bold). Type $(tput sgr0)'confirm'$(tput setaf 4)$(tput bold) to proceed: $(tput sgr0)" confirmation
        if [ "${confirmation}" = "confirm" ]; then
            break
        else
            echo -e "\n$(tput setaf 1)$(tput bold)[ERROR] Invalid confirmation. Terminating the script ... Bye!$(tput sgr0)"
            exit
        fi
    done

    echo -e "\n$(tput setaf 3)$(tput bold)[INFO] Selected Port: '${SELECTED_PORT}'$(tput sgr0)"
}


# run
select_port
