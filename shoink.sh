#!/bin/bash
source .env

ver="v1.2" 

# Colors
red="\e[31m"
green="\e[32m"
blue="\e[34m"
yellow="\e[33m"
cyan="\e[36m"
magenta="\e[35m"
reset="\e[0m"

banner="${yellow}
   _____ __          _       __  
  / ___// /_  ____  (_)___  / /__
  \__ \/ __ \/ __ \/ / __ \/ //_/
 ___/ / / / / /_/ / / / / / ,<   
/____/_/ /_/\____/_/_/ /_/_/|_|     $ver
${reset}
"



services=("TinyURL" "Tinycc" "ulvis.net" "Coming Soon...")

echo -e "$banner\n"
echo -e "${magenta}(*) A URL Shortener...${reset}\n"

# Choose a service function
choose_service() {
    echo -e "(=) Choose a service:\n"
    count=0
    for service in "${services[@]}"; do
        ((count++))
        echo -e "${cyan}$count. $service${reset}"
    done
    echo ""
    read -p "(->) Enter your selection (ex: 1): " service_choice
    echo ""
    service_choice_verifier "$service_choice"
}

# Service identifier function
service_choice_verifier() {
    case "$1" in
        1) tinyurl_options ;;
        2) tinycc_options ;;
        3) ulvisnet_options ;;
        4) echo -e "${yellow}(*) Coming Soon...${reset}" ;;
        *) echo -e "${red}(*) Invalid selection. Exiting.${reset}" ;;
    esac
}

# TinyURL
tinyurl_options() {
    echo -e "${magenta}(*) TinyURL Selected${reset}\n(=) Choose an option:\n"
    echo -e "${cyan}1. Shorten a URL${reset}"
    echo ""
    read -p "(->) Enter your selection (ex: 1): " option_choice

    case "$option_choice" in
        1)
            read -p "(->) Enter the URL to shorten: " long_url

            if [[ -z "$long_url" ]]; then
                echo -e "${red}(*) Error: No URL entered.${reset}"
                return
            fi

            if ! [[ "$long_url" =~ ^https?:// ]]; then
                echo -e "${red}(*) Invalid URL format. Must start with http:// or https://${reset}"
                return
            fi

            read -p "(->) Custom alias (press enter to skip): " custom_alias
            echo -e "(=) Shortening URL: $long_url"

            payload="{\"url\": \"$long_url\""
                    [[ -n "$custom_alias" ]] && payload+=", \"alias\": \"$custom_alias\""
                    payload+="}"

            response=$(curl -s -X POST \
                "https://api.tinyurl.com/create?api_token=$TINYURL_API_KEY" \
                -H "accept: application/json" \
                -H "Authorization: Bearer $TINYURL_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$payload")

            short_url=$(echo "$response" | jq -r '.data.tiny_url // empty')

            if [[ -n "$short_url" ]]; then
                echo -e "\n${green}(*) Shortened URL: $short_url${reset}"
            else
                echo -e "\n${red}(*) Error: Could not shorten URL.\n${reset}(*) ${yellow}Response:\n$response${reset}"
            fi
        ;;
        *) echo "(*) Invalid option. Returning to menu." ;;
    esac
}

# Tinycc
tinycc_options() {
    echo -e "(*) Tinycc Selected\n(=) Feature coming soon...\n"
    read -p "(->) Press Enter to return to menu..." dummy
    choose_service
}

# ulvis.net
ulvisnet_options() {
    echo -e "(*) ulvis.net Selected\n(=) Feature coming soon...\n"
    read -p "(->) Press Enter to return to menu..." dummy
    choose_service
}

# Main function
main() {
    choose_service
}

main
