#!/bin/bash

ver="v1.0"
i=1
banner="
   _____ __          _       __  
  / ___// /_  ____  (_)___  / /__
  \__ \/ __ \/ __ \/ / __ \/ //_/
 ___/ / / / / /_/ / / / / / ,<   
/____/_/ /_/\____/_/_/ /_/_/|_|     $ver
"

services=("TinyURL", "Tinycc", "ulvis.net", "Coming Soon...")

echo -e "$banner\n"
echo -e "(*) A URL Shortener...\n"

# Choose a service function
choose_service() {
    echo -e "(=) Choose a service:\n"

    for service in "${services[@]}"; do
        ((count++))
        echo "($count.) $service"
    done

    echo ""
    read -p "(->) Enter your selection (ex: 1): " service_choice
    echo ""

    service_choice_verifier $service_choice
}

# Service identifier function
service_choice_verifier() {
    if [ $1 -eq 1 ]; then
        tinyurl_options
    elif [ $1 -eq 2 ]; then
        tinycc_options
    elif [ $1 -eq 3 ]; then
        ulvisnet_options
    fi
}

# TinyURL
## Service menu function
tinyurl_options() {
    echo -e "(*) TinyURL Selected\n(=) Choose an option:\n"
    read -p "(->) Enter your selection (ex: 1): " option_choice
    echo ""
}

# Tinycc
## Service menu function
tinycc_options() {
    echo -e "(*) Tinycc Selected\n(=) Choose an option:\n"
    read -p "(->) Enter your selection (ex: 1): " option_choice
    echo ""
}

# ulvis.net
## Service menu function
ulvisnet_options() {
    echo -e "(*) ulvis.net Selected\n(=) Choose an option:\n"
    read -p "(->) Enter your selection (ex: 1): " option_choice
    echo ""
}

# Main function
main() {
    choose_service
}

main