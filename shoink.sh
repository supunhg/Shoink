#!/bin/bash
source .env

ver="v1.3" 

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

# Choose a service function
choose_service() {
    echo -e "(=) Choose a service:\n"

    echo -e "${cyan}1. TinyURL${reset}"
    echo -e "${cyan}2. TinyCC${reset}"
    echo -e "${cyan}3. ulvis.net${reset}"
    echo -e "${cyan}4. Coming soon...${reset}"
    echo -e "${cyan}5. Exit${reset}"

    echo ""
    read -p "(->) Enter your selection (ex: 1): " service_choice
    [[ "$service_choice" == "/q" ]] && safe_exit
    echo ""
    service_choice_verifier "$service_choice"
}

# Service identifier function
service_choice_verifier() {
    case "$1" in
        1) tinyurl_options ;;
        2) tinycc_options ;;
        3) ulvisnet_options ;;
        4) coming_soon ;;
        5) safe_exit ;;
        *) main_menu 1;;
    esac
}

# Exit function
safe_exit() {
    echo -e "${yellow}Quitting...${reset}"
    exit 0
}

# Coming soon function
coming_soon() {
    echo -e "${yellow}(*) Coming Soon${reset}" 
    read -p "(->) Press Enter to return to menu..." random
}

# Return to menu function
main_menu() {
    if [[ $1 == 1 ]]; then
        echo -e "${red}(*) Invalid option.${reset}" 
        read -p "(->) Press Enter to return to menu..." random
        return
    elif [[ $1 == 2 ]]; then
        read -p "(->) Press Enter to return to menu..." random
        return
    fi
}

wait_for_input() {
    echo -e "${yellow}(*) Press Enter to continue...${reset}"
    read -r
}

# TinyURL
tinyurl_options() {
    echo -e "${magenta}(*) TinyURL Selected${reset}\n(=) Choose an option:\n"

    echo -e "${cyan}1. Shorten a URL${reset}"
    echo -e "${cyan}2. Update an existing alias${reset}"
    echo -e "${cyan}3. Get TinyURL information${reset}"
    echo -e "${cyan}4. Get a list of TinyURLs${reset}"
    echo -e "${cyan}5. Get count of TinyURLs${reset}"
    echo -e "${cyan}6. Go back${reset}"
    echo -e "${cyan}7. Exit${reset}"

    echo ""
    read -p "(->) Enter your selection (ex: 1): " option_choice

    case "$option_choice" in
        1)
            while true; do
                read -p "(->) Enter the URL to shorten: " long_url

                if [[ "$long_url" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$long_url" ]]; then
                    echo -e "${red}(*) No URL entered.${reset}\n"
                    continue
                fi

                if ! [[ "$long_url" =~ ^https?:// ]]; then
                    echo -e "${red}(*) Invalid URL format. Must start with http:// or https://${reset}\n"
                    continue
                fi

                break
            done

            while true; do
                read -p "(->) Custom alias (press enter to skip): " custom_alias

                if [[ "$custom_alias" == "/q" ]]; then
                    safe_exit
                fi

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

                short_url=$(echo "$response" | jq -r '.data.tiny_url? // empty')
                error_message=$(echo "$response" | jq -r '.errors[0] // empty')

                if [[ -n "$short_url" ]]; then
                    echo -e "\n${green}(*) Shortened URL: $short_url${reset}"
                    main_menu 2
                    break
                elif [[ "$error_message" == "Alias is not available." ]]; then
                    echo -e "${red}(*) Alias already taken. Please try another.${reset}\n"
                    continue
                else
                    echo -e "\n${red}(*) Error: Could not shorten URL.\n${reset}${yellow}(*) Response:\n$response${reset}"
                    main_menu 2
                    break
                fi
            done
        ;;
        2)
            while true; do
                read -p "(->) Enter the alias you wish to update: " old_alias

                if [[ "$old_alias" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$old_alias" ]]; then
                    echo -e "${red}(*) No alias entered.${reset}\n"
                    continue
                fi

                break
            done

            while true; do
                read -p "(->) Enter the new alias: " new_alias

                if [[ "$new_alias" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$new_alias" ]]; then
                    echo -e "${red}(*) No alias entered.${reset}\n"
                    continue
                fi

                echo -e "(=) Updating URL for alias: ${magenta}$old_alias${reset} to ${magenta}$new_alias${reset}"

                payload="{\"alias\": \"$old_alias\", \"new_alias\": \"$new_alias\"}"

                response=$(curl -s -X 'PATCH' \
                        "https://api.tinyurl.com/update?api_token=$TINYURL_API_KEY" \
                        -H 'accept: application/json' \
                        -H "Authorization: Bearer $TINYURL_API_KEY" \
                        -H 'Content-Type: application/json' \
                        -d "$payload")

                short_url=$(echo "$response" | jq -r '.data.tiny_url? // empty')
                error_message=$(echo "$response" | jq -r '.errors[0] // empty')

                if [[ -n "$short_url" ]]; then
                    echo -e "\n${green}(*) Alias updated successfully: $short_url${reset}"
                    main_menu 2
                elif [[ "$error_message" == "Alias is not available." ]]; then
                    echo -e "${red}(*) The alias is not available.${reset}\n"
                    wait_for_input
                    continue
                elif [[ "$error_message" == "The Alias format is invalid." ]]; then
                    echo -e "${red}(*) The alias format is invalid.${reset}\n"
                    wait_for_input
                    continue
                elif [[ "$error_message" == "The Alias must not be greater than 30 characters." ]]; then
                    echo -e "${red}(*) The alias must not be greater than 30 characters.${reset}\n"
                    wait_for_input
                    continue
                elif [[ "$error_message" == "Something went wrong." ]]; then
                    echo -e "${red}(*) Something went wrong.${reset}\n"
                    wait_for_input
                    continue
                else
                    echo -e "\n${red}(*) Could not update alias.\n${reset}${yellow}(*) Response:\n$response${reset}"
                    wait_for_input
                    continue
                fi

                break
            done
        ;;
        3)
            while true; do
                read -p "(->) Enter a TinyURL: " tinyurl

                if [[ "$tinyurl" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$tinyurl" ]]; then
                    echo -e "${red}(*) No TinyURL entered.${reset}\n"
                    continue
                fi

                if [[ "$tinyurl" =~ ^https?:// ]]; then
                    formatted_tinyurl="${tinyurl#*://}"
                    domain="${formatted_tinyurl%%/*}"
                    alias="${formatted_tinyurl#*/}"
                else
                    domain="tinyurl.com"
                    alias="$tinyurl"
                fi

                echo -e "(=) Fetching information for alias: ${magenta}$alias${reset} on domain ${magenta}$domain${reset}"

                response=$(curl -s -X 'GET' \
                        "https://api.tinyurl.com/alias/$domain/$alias?api_token=$TINYURL_API_KEY" \
                        -H 'accept: application/json' \
                        -H "Authorization: Bearer $TINYURL_API_KEY")
                
                fetched_domain=$(echo "$response" | jq -r '.data.domain? // empty')
                fetched_alias=$(echo "$response" | jq -r '.data.alias? // empty')
                created_at=$(echo "$response" | jq -r '.data.created_at? // empty')
                user_name=$(echo "$response" | jq -r '.data.user.name? // empty')
                user_email=$(echo "$response" | jq -r '.data.user.email? // empty')
                long_url=$(echo "$response" | jq -r '.data.url? // empty')

                echo -e "\n${green}(*) Information for alias: $fetched_alias${reset}"
                printf "  ${magenta}Domain:${reset}   %s\n" "$fetched_domain"
                printf "  ${magenta}Alias:${reset}    %s\n" "$fetched_alias"
                printf "  ${magenta}Long URL:${reset} %s\n" "$long_url"
                printf "  ${magenta}Created:${reset}  %s\n" "$created_at"
                printf "  ${magenta}User:${reset}     %s\n" "$user_name" 
                printf "  ${magenta}Email:${reset}    %s\n\n" "$user_email"

                wait_for_input

                break
            done
        ;;
        4)
            while true; do
                read -p "(->) Search for an alias (press enter to list all): " search_alias

                if [[ "$search_alias" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$search_alias" ]]; then
                    echo -e "(=) Listing all TinyURLs..."
                    response=$(curl -s -X 'GET' \
                            "https://api.tinyurl.com/urls/available?api_token=$TINYURL_API_KEY" \
                            -H 'accept: application/json' \
                            -H "Authorization: Bearer $TINYURL_API_KEY")
                else
                    echo -e "(=) Searching for alias: ${magenta}$search_alias${reset}"
                    response=$(curl -s -X 'GET' \
                            "https://api.tinyurl.com/urls/available?search=alias%3A$search_alias&api_token=$TINYURL_API_KEY" \
                            -H 'accept: application/json' \
                            -H "Authorization: Bearer $TINYURL_API_KEY")
                fi

                if [[ $(echo "$response" | jq -r '.data | length') -eq 0 ]]; then
                    echo -e "${red}(*) No TinyURLs found.${reset}\n"
                    wait_for_input
                    continue
                fi

                echo -e "\n${green}(*) TinyURLs found:${reset}"

                i=1
                echo "$response" | jq -r '.data[] | "\(.alias) |\(.tiny_url) |\(.created_at)"' | while IFS='|' read -r alias tiny_url created_at; do
                    created_date=$(echo "$created_at" | cut -d'T' -f1)
                    printf "  ${cyan}%2d.${reset} ${magenta}%-25s${reset} - %-30s - Created at: ${yellow}%s${reset}\n" "$i" "$alias" "$tiny_url" "$created_date"
                    ((i++))
                done

                echo ""
                wait_for_input
                
                break
            done
        ;;
        5)
            while true; do

                read -p "(->) Enter an alias to get its count (press enter to get total count): " alias_count

                if [[ "$alias_count" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$alias_count" ]]; then
                    echo -e "(=) Getting total count of TinyURLs..."
                    response=$(curl -s -X 'GET' \
                            "https://api.tinyurl.com/urls/available/count?api_token=$TINYURL_API_KEY" \
                            -H 'accept: application/json' \
                            -H "Authorization: Bearer $TINYURL_API_KEY")
                else
                    echo -e "(=) Getting count for alias: ${magenta}$alias_count${reset}"
                    response=$(curl -s -X 'GET' \
                        "https://api.tinyurl.com/urls/available/count?search=alias%3A$alias_count&api_token=$TINYURL_API_KEY" \
                        -H 'accept: application/json' \
                        -H "Authorization: Bearer $TINYURL_API_KEY")
                fi

                count=$(echo "$response" | jq -r '.data.count? // empty')

                if [[ -z "$alias_count" ]]; then
                    echo -e "\n${green}(*) Total alias count is: ${yellow}$count${reset}\n"
                else
                    echo -e "\n${green}(*) Count for alias: ${magenta}$alias_count${reset} is ${yellow}$count${reset}\n"
                fi

                wait_for_input

                break
            done
        ;;
        6) return ;;
        7) safe_exit ;;
        *) 
            echo -e "(*) Invalid option: \"$option_choice\"\n" 
            tinyurl_options
        ;;
    esac
}

# Tinycc
tinycc_options() {

    echo -e "${magenta}(*) Tinycc Selected${reset}\n(=) Choose an option:\n"

    echo -e "${cyan}1. Shorten a URL${reset}"
    echo -e "${cyan}2. Get a list of TinyCC URLs${reset}"
    echo -e "${cyan}3. Get account information${reset}"
    echo -e "${cyan}4. Edit a TinyCC URL${reset}"
    echo -e "${cyan}5. Go back${reset}"
    echo -e "${cyan}6. Exit${reset}"

    echo ""
    read -p "(->) Enter your selection (ex: 1): " option_choice

    case "$option_choice" in
        1)
            while true; do
                read -p "(->) Enter the URL to shorten: " long_url

                if [[ "$long_url" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$long_url" ]]; then
                    echo -e "${red}(*) No URL entered.${reset}\n"
                    continue
                fi

                if ! [[ "$long_url" =~ ^https?:// ]]; then
                    echo -e "${red}(*) Invalid URL format. Must start with http:// or https://${reset}\n"
                    continue
                fi

                break
            done

            while true; do
                read -p "(->) Custom alias (press enter to skip): " custom_alias

                if [[ "$custom_alias" == "/q" ]]; then
                    safe_exit
                fi

                echo -e "(=) Shortening URL: $long_url"

                payload="{\"urls\": [{\"long_url\": \"$long_url\""
                        [[ -n "$custom_alias" ]] && payload+=", \"custom_hash\": \"$custom_alias\""
                        payload+="}]}"

                response=$(curl -s -X POST \
                    "https://tiny.cc/tiny/api/3/urls" \
                    -H "X-Tinycc-User: $TINYCC_USER" \
                    -H "X-Tinycc-Key: $TINYCC_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "$payload")

                short_url_with_protocol=$(echo "$response" | jq -r '.urls[0].short_url_with_protocol? // empty')
                error_code=$(echo "$response" | jq -r '.urls[0].error.code? // empty')
                error_details=$(echo "$response" | jq -r '.urls[0].error.details? // empty')

                if [[ -n "$short_url_with_protocol" ]]; then
                    echo -e "\n${green}(*) Shortened URL: $short_url_with_protocol${reset}"
                    main_menu 2
                    break
                elif [[ "$error_code" == "1215" ]]; then
                    echo -e "\n${red}(*) $error_details${reset}"
                    wait_for_input
                    continue
                else
                    echo -e "\n${red}(*) Could not shorten URL.\n${reset}${yellow}(*) Error details:\n$error_details${reset}"
                    wait_for_input
                    continue
                fi
            done
        ;;

        2) 
            read -p "(->) Enter a search term (press enter to list all): " search_term
            if [[ "$search_term" == "/q" ]]; then
                safe_exit
            fi

            if [[ -z "$search_term" ]]; then
                echo -e "(=) Listing all TinyCC URLs..."
                response=$(curl -s -X GET \
                    "https://tiny.cc/tiny/api/3/urls" \
                    -H "X-Tinycc-User: $TINYCC_USER" \
                    -H "X-Tinycc-Key: $TINYCC_API_KEY")
            else
                echo -e "(=) Searching for URLs with term: ${magenta}$search_term${reset}"
                response=$(curl -s -X GET \
                    "https://tiny.cc/tiny/api/3/urls?search=$search_term&limit=100" \
                    -H "X-Tinycc-User: $TINYCC_USER" \
                    -H "X-Tinycc-Key: $TINYCC_API_KEY")
            fi

            if [[ $(echo "$response" | jq -r '.urls | length') -eq 0 ]]; then
                echo -e "\n${red}(*) No TinyCC URLs found.${reset}\n"
            else
                echo -e "\n${green}(*) TinyCC URLs found:${reset}"
                i=1
                echo "$response" | jq -r '.urls[] | "\(.hash) |\(.short_url_with_protocol) | \(.long_url) | \(.created_at) | \(.clicks)"' | while IFS='|' read -r hash short_url long_url created_at clicks; do
                created_date=$(echo "$created_at" | cut -d'T' -f1)
                printf "  ${cyan}%2d.${reset} ${magenta}%-10s${reset} - %-30s - %-40s\n" "$i" "$hash" "$short_url" "$long_url"
                ((i++))
                done
                echo ""
            fi

            wait_for_input
            break
        ;;
        3) 
            echo -e "(=) Fetching account information..."
            response=$(curl -s -X GET \
                "https://tiny.cc/tiny/api/3/account" \
                -H "X-Tinycc-User: $TINYCC_USER" \
                -H "X-Tinycc-Key: $TINYCC_API_KEY")

            if [[ $(echo "$response" | jq -r '.account | length') -eq 0 ]]; then
                echo -e "\n${red}(*) Could not fetch account information.${reset}\n"
                wait_for_input
                return
            fi

            user_id=$(echo "$response" | jq -r '.account.user_id? // empty')
            user_name=$(echo "$response" | jq -r '.account.username? // empty')
            total_urls=$(echo "$response" | jq -r '.account.counters.urls.count? // empty')
            url_limit=$(echo "$response" | jq -r '.account.counters.urls.limit? // empty')

            echo -e "\n${green}(*) Account Information:${reset}"
            printf "  ${magenta}User ID:${reset} %s\n" "$user_id"
            printf "  ${magenta}Username:${reset} %s\n" "$user_name"
            printf "  ${magenta}Total URLs:${reset} %s\n" "$total_urls"
            printf "  ${magenta}URL Limit:${reset} %s\n" "$url_limit"
            echo ""

            wait_for_input
            break
        ;;

        4)
            # Edit a TinyCC URLs long url by giving the hash, new long url and custom alias
            while true; do
                read -p "(->) Enter the hash of the URL to edit: " hash

                if [[ "$hash" == "/q" ]]; then
                    safe_exit
                fi

                if [[ -z "$hash" ]]; then
                    echo -e "${red}(*) No hash entered.${reset}\n"
                    continue
                fi

                read -p "(->) Enter the new long URL: " new_long_url

                if [[ "$new_long_url" == "/q" ]]; then
                    safe_exit
                fi

                read -p "(->) Enter the new custom alias (press enter to skip): " new_alias

                if [[ "$new_alias" == "/q" ]]; then
                    safe_exit
                fi

                echo -e "(=) Updating URL with hash: ${magenta}$hash${reset} to new long URL: ${magenta}$new_long_url${reset} and new alias: ${magenta}$new_alias${reset}"

                payload="{\"urls\": [{\"hash\": \"$hash\", \"long_url\": \"$new_long_url\""
                [[ -n "$new_alias" ]] && payload+=", \"custom_hash\": \"$new_alias\""
                payload+="}]}"
                response=$(curl -s -X PATCH \
                    "https://tiny.cc/tiny/api/3/urls" \
                    -H "X-Tinycc-User: $TINYCC_USER" \
                    -H "X-Tinycc-Key: $TINYCC_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "$payload")

                short_url_with_protocol=$(echo "$response" | jq -r '.urls[0].short_url_with_protocol? // empty')
                error_code=$(echo "$response" | jq -r '.urls[0].error.code? // empty')
                error_details=$(echo "$response" | jq -r '.urls[0].error.details? // empty')

                if [[ -n "$short_url_with_protocol" ]]; then
                    echo -e "\n${green}(*) URL updated successfully: $short_url_with_protocol${reset}"
                    main_menu 2
                    break
                elif [[ "$error_code" == "1216" ]]; then
                    echo -e "\n${red}(*) The Domain is not allowed.${reset}"
                    wait_for_input
                    continue
                else
                    echo -e "\n${red}(*) Could not update URL.\n${reset}${yellow}(*) Error details:\n$error_details${reset}"
                    wait_for_input
                    continue
                fi

            done
        ;;

        5) return ;;
        6) safe_exit ;;
        *) 
            echo -e "(*) Invalid option: \"$option_choice\"\n" 
            tinyurl_options
        ;;
    esac
}

# ulvis.net
ulvisnet_options() {
    echo -e "${magenta}(*) ulvis.net Selected${reset}\n${yellow}(=) Feature coming soon...${reset}\n"
    read -p "(->) Press Enter to return to menu..." random
    return
}

# Main function
main() {
    while true; do
        clear
        echo -e "$banner\n"
        echo -e "${magenta}(*) A URL Shortener...${reset}\n"
        choose_service
    done
}

main
