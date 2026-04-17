#!/usr/bin/env bash

set -o pipefail

ver="v1.4"
script_name="${0##*/}"
env_file=".env"

if [[ -t 1 ]]; then
    red=$'\e[31m'
    green=$'\e[32m'
    blue=$'\e[34m'
    yellow=$'\e[33m'
    cyan=$'\e[36m'
    magenta=$'\e[35m'
    reset=$'\e[0m'
else
    red=""
    green=""
    blue=""
    yellow=""
    cyan=""
    magenta=""
    reset=""
fi

banner="${yellow}
   _____ __          _       __
  / ___// /_  ____  (_)___  / /__
  \__ \/ __ \/ __ \/ / __ \/ //_/
 ___/ / / / / /_/ / / / / / ,<
/____/_/ /_/\____/_/_/ /_/_/|_|     ${ver}
${reset}"

CURL_OPTS=(
    --silent
    --show-error
    --location
    --connect-timeout 10
    --max-time 30
)

print_info() {
    echo -e "${yellow}(=) $1${reset}"
}

print_success() {
    echo -e "${green}(*) $1${reset}"
}

print_error() {
    echo -e "${red}(*) $1${reset}" >&2
}

wait_for_input() {
    echo -e "${yellow}(*) Press Enter to continue...${reset}"
    read -r
}

safe_exit() {
    echo -e "${yellow}Quitting...${reset}"
    exit 0
}

safe_clear() {
    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
        clear
    fi
}

show_banner() {
    safe_clear
    echo -e "${banner}\n"
    echo -e "${magenta}(*) A terminal-first URL shortener${reset}\n"
}

show_usage() {
    cat <<EOF
Shoink ${ver}

Usage:
  ${script_name}
  ${script_name} --service tinyurl --url https://example.com [--alias demo]
  ${script_name} --service tinycc --url https://example.com [--alias demo]
  ${script_name} --service ulvis --url https://example.com [--alias demo] [--private] [--password 1234] [--uses 5] [--expire 12/31/2026]
  ${script_name} --service tinyurl --lookup demo
  ${script_name} --service ulvis --lookup demo [--password 1234]

Options:
  --service SERVICE   One of: tinyurl, tinycc, ulvis
  --url URL           Shorten a URL non-interactively
  --alias VALUE       Optional custom alias
  --lookup VALUE      Look up an existing TinyURL or ulvis short code
  --private           ulvis only: create a private link
  --password VALUE    ulvis only: protect a link with a password (max 10 chars)
  --uses NUMBER       ulvis only: max uses before inactivation
  --expire MM/DD/YYYY ulvis only: expiration date
  --help              Show this help text
  --version           Print the current version

Interactive tips:
  - Enter /q at any prompt to quit immediately.
EOF
}

load_env() {
    if [[ ! -f "$env_file" ]]; then
        return 0
    fi

    set -a
    # shellcheck disable=SC1090
    source <(tr -d '\r' < "$env_file")
    set +a
}

check_dependencies() {
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if (( ${#missing[@]} > 0 )); then
        print_error "Missing required dependencies: ${missing[*]}"
        echo "Install them and run ${script_name} again."
        exit 1
    fi
}

ensure_tinyurl_config() {
    if [[ -z "${TINYURL_API_KEY:-}" ]]; then
        print_error "TINYURL_API_KEY is missing. Add it to ${env_file} to use TinyURL."
        return 1
    fi

    return 0
}

ensure_tinycc_config() {
    if [[ -z "${TINYCC_USER:-}" || -z "${TINYCC_API_KEY:-}" ]]; then
        print_error "TINYCC_USER or TINYCC_API_KEY is missing. Add both to ${env_file} to use Tiny.cc."
        return 1
    fi

    return 0
}

run_request() {
    local __resultvar="$1"
    shift

    local output
    if ! output="$("$@" 2>&1)"; then
        print_error "Request failed: ${output}"
        return 1
    fi

    printf -v "$__resultvar" '%s' "$output"
}

is_json() {
    jq -e . >/dev/null 2>&1 <<<"$1"
}

is_cloudflare_challenge() {
    [[ "$1" == *"Just a moment..."* || "$1" == *"Enable JavaScript and cookies to continue"* || "$1" == *"_cf_chl_opt"* ]]
}

urlencode() {
    jq -nr --arg value "$1" '$value | @uri'
}

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

lowercase() {
    printf '%s' "${1,,}"
}

is_valid_url() {
    [[ "$1" =~ ^https?://[^[:space:]]+$ ]]
}

is_valid_alias() {
    [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]
}

is_valid_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_valid_expire_date() {
    [[ "$1" =~ ^(0[1-9]|1[0-2])/(0[1-9]|[12][0-9]|3[01])/[0-9]{4}$ ]]
}

format_unix_timestamp() {
    local ts="$1"

    if [[ ! "$ts" =~ ^[0-9]+$ ]]; then
        printf '%s' "$ts"
        return
    fi

    if date -d "@${ts}" "+%Y-%m-%d %H:%M:%S %Z" >/dev/null 2>&1; then
        date -d "@${ts}" "+%Y-%m-%d %H:%M:%S %Z"
        return
    fi

    if date -r "${ts}" "+%Y-%m-%d %H:%M:%S %Z" >/dev/null 2>&1; then
        date -r "${ts}" "+%Y-%m-%d %H:%M:%S %Z"
        return
    fi

    printf '%s' "$ts"
}

read_with_quit() {
    local __resultvar="$1"
    local prompt="$2"
    local value

    read -r -p "$prompt" value
    if [[ "$value" == "/q" ]]; then
        safe_exit
    fi

    printf -v "$__resultvar" '%s' "$value"
}

prompt_required_url() {
    local __resultvar="$1"
    local prompt="$2"
    local value

    while true; do
        read_with_quit value "$prompt"
        value="$(trim "$value")"

        if [[ -z "$value" ]]; then
            print_error "No URL entered."
            continue
        fi

        if ! is_valid_url "$value"; then
            print_error "Invalid URL format. Use http:// or https://."
            continue
        fi

        printf -v "$__resultvar" '%s' "$value"
        return 0
    done
}

prompt_optional_alias() {
    local __resultvar="$1"
    local prompt="$2"
    local max_length="$3"
    local value

    while true; do
        read_with_quit value "$prompt"
        value="$(trim "$value")"

        if [[ -z "$value" ]]; then
            printf -v "$__resultvar" '%s' ""
            return 0
        fi

        if ! is_valid_alias "$value"; then
            print_error "Alias can only use letters, numbers, underscores, and hyphens."
            continue
        fi

        if (( ${#value} > max_length )); then
            print_error "Alias must be ${max_length} characters or fewer."
            continue
        fi

        printf -v "$__resultvar" '%s' "$value"
        return 0
    done
}

prompt_required_alias() {
    local __resultvar="$1"
    local prompt="$2"
    local max_length="$3"
    local value

    while true; do
        read_with_quit value "$prompt"
        value="$(trim "$value")"

        if [[ -z "$value" ]]; then
            print_error "No alias entered."
            continue
        fi

        if ! is_valid_alias "$value"; then
            print_error "Alias can only use letters, numbers, underscores, and hyphens."
            continue
        fi

        if (( ${#value} > max_length )); then
            print_error "Alias must be ${max_length} characters or fewer."
            continue
        fi

        printf -v "$__resultvar" '%s' "$value"
        return 0
    done
}

prompt_optional_password() {
    local __resultvar="$1"
    local prompt="$2"
    local value

    while true; do
        read_with_quit value "$prompt"
        value="$(trim "$value")"

        if [[ -z "$value" ]]; then
            printf -v "$__resultvar" '%s' ""
            return 0
        fi

        if (( ${#value} > 10 )); then
            print_error "Password must be 10 characters or fewer for ulvis."
            continue
        fi

        printf -v "$__resultvar" '%s' "$value"
        return 0
    done
}

prompt_optional_positive_integer() {
    local __resultvar="$1"
    local prompt="$2"
    local value

    while true; do
        read_with_quit value "$prompt"
        value="$(trim "$value")"

        if [[ -z "$value" ]]; then
            printf -v "$__resultvar" '%s' ""
            return 0
        fi

        if ! is_valid_positive_integer "$value"; then
            print_error "Enter a positive whole number."
            continue
        fi

        printf -v "$__resultvar" '%s' "$value"
        return 0
    done
}

prompt_optional_expire_date() {
    local __resultvar="$1"
    local prompt="$2"
    local value

    while true; do
        read_with_quit value "$prompt"
        value="$(trim "$value")"

        if [[ -z "$value" ]]; then
            printf -v "$__resultvar" '%s' ""
            return 0
        fi

        if ! is_valid_expire_date "$value"; then
            print_error "Enter the date as MM/DD/YYYY."
            continue
        fi

        printf -v "$__resultvar" '%s' "$value"
        return 0
    done
}

ask_yes_no() {
    local prompt="$1"
    local default_answer="$2"
    local answer

    while true; do
        read_with_quit answer "$prompt"
        answer="$(lowercase "$(trim "$answer")")"

        if [[ -z "$answer" ]]; then
            [[ "$default_answer" == "yes" ]]
            return
        fi

        case "$answer" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) print_error "Please answer with y or n." ;;
        esac
    done
}

parse_tinyurl_identifier() {
    local input="$1"
    local clean domain alias

    clean="${input#http://}"
    clean="${clean#https://}"
    clean="${clean%%\?*}"
    clean="${clean%%#*}"
    clean="${clean%/}"

    if [[ "$clean" == */* ]]; then
        domain="${clean%%/*}"
        alias="${clean#*/}"
    else
        domain="tinyurl.com"
        alias="$clean"
    fi

    printf '%s\n%s\n' "$domain" "$alias"
}

normalize_ulvis_id() {
    local input="$1"

    input="${input#http://}"
    input="${input#https://}"
    input="${input#ulvis.net/}"
    input="${input%%\?*}"
    input="${input%%#*}"
    input="${input%/}"

    printf '%s' "$input"
}

tinyurl_request() {
    local method="$1"
    local endpoint="$2"
    local payload="${3:-}"
    local args=(
        "${CURL_OPTS[@]}"
        -X "$method"
        "https://api.tinyurl.com${endpoint}"
        -H "accept: application/json"
        -H "Authorization: Bearer ${TINYURL_API_KEY}"
    )

    if [[ -n "$payload" ]]; then
        args+=(
            -H "Content-Type: application/json"
            -d "$payload"
        )
    fi

    curl "${args[@]}"
}

tinycc_request() {
    local method="$1"
    local endpoint="$2"
    local payload="${3:-}"
    local args=(
        "${CURL_OPTS[@]}"
        -X "$method"
        "https://tiny.cc/tiny/api/3/${endpoint}"
        -H "X-Tinycc-User: ${TINYCC_USER}"
        -H "X-Tinycc-Key: ${TINYCC_API_KEY}"
        -H "accept: application/json"
    )

    if [[ -n "$payload" ]]; then
        args+=(
            -H "Content-Type: application/json"
            -d "$payload"
        )
    fi

    curl "${args[@]}"
}

ulvis_write_request() {
    local long_url="$1"
    local custom_alias="$2"
    local private_flag="$3"
    local password="$4"
    local uses="$5"
    local expire="$6"
    local args=(
        "${CURL_OPTS[@]}"
        --get
        "https://ulvis.net/API/write/get"
        --data-urlencode "url=${long_url}"
        --data-urlencode "type=json"
        --data-urlencode "via=shoink"
    )

    if [[ -n "$custom_alias" ]]; then
        args+=(--data-urlencode "custom=${custom_alias}")
    fi

    if [[ "$private_flag" == "1" ]]; then
        args+=(--data-urlencode "private=1")
    fi

    if [[ -n "$password" ]]; then
        args+=(--data-urlencode "password=${password}")
    fi

    if [[ -n "$uses" ]]; then
        args+=(--data-urlencode "uses=${uses}")
    fi

    if [[ -n "$expire" ]]; then
        args+=(--data-urlencode "expire=${expire}")
    fi

    curl "${args[@]}"
}

ulvis_read_request() {
    local identifier="$1"
    local password="$2"
    local args=(
        "${CURL_OPTS[@]}"
        --get
        "https://ulvis.net/API/read/get"
        --data-urlencode "id=${identifier}"
        --data-urlencode "type=json"
    )

    if [[ -n "$password" ]]; then
        args+=(--data-urlencode "password=${password}")
    fi

    curl "${args[@]}"
}

tinyurl_shorten() {
    local long_url="$1"
    local custom_alias="${2:-}"
    local payload response short_url error_message

    ensure_tinyurl_config || return 1

    payload="$(jq -n --arg url "$long_url" --arg alias "$custom_alias" \
        '{url: $url} + (if $alias == "" then {} else {alias: $alias} end)')"

    run_request response tinyurl_request POST "/create" "$payload" || return 1

    if ! is_json "$response"; then
        print_error "TinyURL returned a non-JSON response."
        return 1
    fi

    short_url="$(jq -r '.data.tiny_url // empty' <<<"$response" 2>/dev/null)"
    error_message="$(jq -r '.errors[0] // .message // empty' <<<"$response" 2>/dev/null)"

    if [[ -n "$short_url" ]]; then
        printf '%s' "$short_url"
        return 0
    fi

    print_error "${error_message:-Could not shorten the URL with TinyURL.}"
    return 1
}

tinyurl_update_alias() {
    local old_alias="$1"
    local new_alias="$2"
    local payload response short_url error_message

    ensure_tinyurl_config || return 1

    payload="$(jq -n --arg alias "$old_alias" --arg new_alias "$new_alias" \
        '{alias: $alias, new_alias: $new_alias}')"

    run_request response tinyurl_request PATCH "/update" "$payload" || return 1

    if ! is_json "$response"; then
        print_error "TinyURL returned a non-JSON response."
        return 1
    fi

    short_url="$(jq -r '.data.tiny_url // empty' <<<"$response" 2>/dev/null)"
    error_message="$(jq -r '.errors[0] // .message // empty' <<<"$response" 2>/dev/null)"

    if [[ -n "$short_url" ]]; then
        printf '%s' "$short_url"
        return 0
    fi

    print_error "${error_message:-Could not update the TinyURL alias.}"
    return 1
}

tinyurl_lookup() {
    local identifier="$1"
    local domain alias response

    ensure_tinyurl_config || return 1

    mapfile -t identifier_parts < <(parse_tinyurl_identifier "$identifier")
    domain="${identifier_parts[0]}"
    alias="${identifier_parts[1]}"

    if [[ -z "$alias" ]]; then
        print_error "Enter a TinyURL alias or URL to inspect."
        return 1
    fi

    run_request response tinyurl_request GET "/alias/${domain}/${alias}" || return 1

    if ! is_json "$response"; then
        print_error "TinyURL returned a non-JSON response."
        return 1
    fi

    if [[ -z "$(jq -r '.data.alias // empty' <<<"$response" 2>/dev/null)" ]]; then
        print_error "$(jq -r '.errors[0] // .message // "Could not fetch TinyURL information."' <<<"$response" 2>/dev/null)"
        return 1
    fi

    printf '%s' "$response"
}

tinyurl_list() {
    local search_alias="$1"
    local response endpoint

    ensure_tinyurl_config || return 1

    endpoint="/urls/available"
    if [[ -n "$search_alias" ]]; then
        endpoint+="?search=$(urlencode "alias:${search_alias}")"
    fi

    run_request response tinyurl_request GET "$endpoint" || return 1

    if ! is_json "$response"; then
        print_error "TinyURL returned a non-JSON response."
        return 1
    fi

    printf '%s' "$response"
}

tinyurl_count() {
    local alias_filter="$1"
    local response endpoint count

    ensure_tinyurl_config || return 1

    endpoint="/urls/available/count"
    if [[ -n "$alias_filter" ]]; then
        endpoint+="?search=$(urlencode "alias:${alias_filter}")"
    fi

    run_request response tinyurl_request GET "$endpoint" || return 1

    if ! is_json "$response"; then
        print_error "TinyURL returned a non-JSON response."
        return 1
    fi

    count="$(jq -r '.data.count // empty' <<<"$response" 2>/dev/null)"
    if [[ -z "$count" ]]; then
        print_error "$(jq -r '.errors[0] // .message // "Could not read the TinyURL count."' <<<"$response" 2>/dev/null)"
        return 1
    fi

    printf '%s' "$count"
}

tinycc_shorten() {
    local long_url="$1"
    local custom_alias="${2:-}"
    local payload response short_url error_details top_level_error

    ensure_tinycc_config || return 1

    payload="$(jq -n --arg long_url "$long_url" --arg custom_hash "$custom_alias" \
        '{urls: [({long_url: $long_url} + (if $custom_hash == "" then {} else {custom_hash: $custom_hash} end))]}')"

    run_request response tinycc_request POST "urls" "$payload" || return 1

    if ! is_json "$response"; then
        print_error "Tiny.cc returned a non-JSON response."
        return 1
    fi

    short_url="$(jq -r '.urls[0].short_url_with_protocol // empty' <<<"$response" 2>/dev/null)"
    error_details="$(jq -r '.urls[0].error.details // empty' <<<"$response" 2>/dev/null)"
    top_level_error="$(jq -r '.error.message // empty' <<<"$response" 2>/dev/null)"

    if [[ -n "$short_url" ]]; then
        printf '%s' "$short_url"
        return 0
    fi

    print_error "${error_details:-${top_level_error:-Could not shorten the URL with Tiny.cc.}}"
    return 1
}

tinycc_list() {
    local search_term="$1"
    local endpoint response

    ensure_tinycc_config || return 1

    endpoint="urls"
    if [[ -n "$search_term" ]]; then
        endpoint+="?search=$(urlencode "$search_term")&limit=100"
    fi

    run_request response tinycc_request GET "$endpoint" || return 1

    if ! is_json "$response"; then
        print_error "Tiny.cc returned a non-JSON response."
        return 1
    fi

    printf '%s' "$response"
}

tinycc_account_info() {
    local response

    ensure_tinycc_config || return 1

    run_request response tinycc_request GET "account" || return 1

    if ! is_json "$response"; then
        print_error "Tiny.cc returned a non-JSON response."
        return 1
    fi

    if [[ -z "$(jq -r '.account.username // empty' <<<"$response" 2>/dev/null)" ]]; then
        print_error "$(jq -r '.error.message // "Could not fetch Tiny.cc account information."' <<<"$response" 2>/dev/null)"
        return 1
    fi

    printf '%s' "$response"
}

tinycc_edit() {
    local hash="$1"
    local new_long_url="$2"
    local new_alias="$3"
    local payload response short_url error_details top_level_error

    ensure_tinycc_config || return 1

    payload="$(jq -n --arg hash "$hash" --arg long_url "$new_long_url" --arg custom_hash "$new_alias" \
        '{urls: [({hash: $hash, long_url: $long_url} + (if $custom_hash == "" then {} else {custom_hash: $custom_hash} end))]}')"

    run_request response tinycc_request PATCH "urls" "$payload" || return 1

    if ! is_json "$response"; then
        print_error "Tiny.cc returned a non-JSON response."
        return 1
    fi

    short_url="$(jq -r '.urls[0].short_url_with_protocol // empty' <<<"$response" 2>/dev/null)"
    error_details="$(jq -r '.urls[0].error.details // empty' <<<"$response" 2>/dev/null)"
    top_level_error="$(jq -r '.error.message // empty' <<<"$response" 2>/dev/null)"

    if [[ -n "$short_url" ]]; then
        printf '%s' "$short_url"
        return 0
    fi

    print_error "${error_details:-${top_level_error:-Could not update the Tiny.cc URL.}}"
    return 1
}

ulvis_shorten() {
    local long_url="$1"
    local custom_alias="$2"
    local private_flag="$3"
    local password="$4"
    local uses="$5"
    local expire="$6"
    local response short_url success error_message

    run_request response ulvis_write_request "$long_url" "$custom_alias" "$private_flag" "$password" "$uses" "$expire" || return 1

    if is_cloudflare_challenge "$response"; then
        print_error "ulvis.net is currently blocking automated requests behind a Cloudflare challenge."
        return 1
    fi

    if ! is_json "$response"; then
        print_error "ulvis.net returned a non-JSON response."
        return 1
    fi

    success="$(jq -r '.success // empty' <<<"$response" 2>/dev/null)"
    short_url="$(jq -r '.data.url // empty' <<<"$response" 2>/dev/null)"
    error_message="$(jq -r '.error.msg // .message // empty' <<<"$response" 2>/dev/null)"

    if [[ "$success" == "1" || "$success" == "true" ]] && [[ -n "$short_url" ]]; then
        printf '%s' "$short_url"
        return 0
    fi

    print_error "${error_message:-Could not shorten the URL with ulvis.net.}"
    return 1
}

ulvis_lookup() {
    local identifier="$1"
    local password="$2"
    local response success error_message short_url

    identifier="$(normalize_ulvis_id "$identifier")"
    if [[ -z "$identifier" ]]; then
        print_error "Enter a ulvis short code or full ulvis URL."
        return 1
    fi

    run_request response ulvis_read_request "$identifier" "$password" || return 1

    if is_cloudflare_challenge "$response"; then
        print_error "ulvis.net is currently blocking automated requests behind a Cloudflare challenge."
        return 1
    fi

    if ! is_json "$response"; then
        print_error "ulvis.net returned a non-JSON response."
        return 1
    fi

    success="$(jq -r '.success // empty' <<<"$response" 2>/dev/null)"
    short_url="$(jq -r '.data.url // empty' <<<"$response" 2>/dev/null)"
    error_message="$(jq -r '.error.msg // .message // empty' <<<"$response" 2>/dev/null)"

    if [[ "$success" == "1" || "$success" == "true" ]] || [[ -n "$short_url" ]]; then
        printf '%s' "$response"
        return 0
    fi

    print_error "${error_message:-Could not read ulvis URL information.}"
    return 1
}

print_tinyurl_info() {
    local response="$1"
    local domain alias long_url created_at user_name user_email

    domain="$(jq -r '.data.domain // empty' <<<"$response" 2>/dev/null)"
    alias="$(jq -r '.data.alias // empty' <<<"$response" 2>/dev/null)"
    long_url="$(jq -r '.data.url // empty' <<<"$response" 2>/dev/null)"
    created_at="$(jq -r '.data.created_at // empty' <<<"$response" 2>/dev/null)"
    user_name="$(jq -r '.data.user.name // empty' <<<"$response" 2>/dev/null)"
    user_email="$(jq -r '.data.user.email // empty' <<<"$response" 2>/dev/null)"

    print_success "Information for alias: ${alias}"
    printf "  ${magenta}Domain:${reset}   %s\n" "$domain"
    printf "  ${magenta}Alias:${reset}    %s\n" "$alias"
    printf "  ${magenta}Long URL:${reset} %s\n" "$long_url"
    printf "  ${magenta}Created:${reset}  %s\n" "$created_at"
    printf "  ${magenta}User:${reset}     %s\n" "${user_name:-n/a}"
    printf "  ${magenta}Email:${reset}    %s\n" "${user_email:-n/a}"
    echo ""
}

print_tinyurl_list() {
    local response="$1"
    local count

    count="$(jq -r '.data | length // 0' <<<"$response" 2>/dev/null)"
    if [[ "$count" == "0" ]]; then
        print_error "No TinyURLs found."
        return 1
    fi

    print_success "TinyURLs found:"
    jq -r '.data[] | [.alias, .tiny_url, .created_at] | @tsv' <<<"$response" 2>/dev/null | \
    awk -F '\t' -v cyan="$cyan" -v magenta="$magenta" -v yellow="$yellow" -v reset="$reset" '
        {
            split($3, created_parts, "T")
            printf "  %s%2d.%s %s%-25s%s - %-30s - Created at: %s%s%s\n",
                cyan, NR, reset, magenta, $1, reset, $2, yellow, created_parts[1], reset
        }
    '
    echo ""
}

print_tinycc_list() {
    local response="$1"
    local count

    count="$(jq -r '.urls | length // 0' <<<"$response" 2>/dev/null)"
    if [[ "$count" == "0" ]]; then
        print_error "No Tiny.cc URLs found."
        return 1
    fi

    print_success "Tiny.cc URLs found:"
    jq -r '.urls[] | [.hash, .short_url_with_protocol, .long_url] | @tsv' <<<"$response" 2>/dev/null | \
    awk -F '\t' -v cyan="$cyan" -v magenta="$magenta" -v reset="$reset" '
        {
            printf "  %s%2d.%s %s%-10s%s - %-30s - %s\n",
                cyan, NR, reset, magenta, $1, reset, $2, $3
        }
    '
    echo ""
}

print_tinycc_account_info() {
    local response="$1"
    local user_id user_name total_urls url_limit

    user_id="$(jq -r '.account.user_id // empty' <<<"$response" 2>/dev/null)"
    user_name="$(jq -r '.account.username // empty' <<<"$response" 2>/dev/null)"
    total_urls="$(jq -r '.account.counters.urls.count // empty' <<<"$response" 2>/dev/null)"
    url_limit="$(jq -r '.account.counters.urls.limit // empty' <<<"$response" 2>/dev/null)"

    print_success "Tiny.cc account information:"
    printf "  ${magenta}User ID:${reset}    %s\n" "$user_id"
    printf "  ${magenta}Username:${reset}   %s\n" "$user_name"
    printf "  ${magenta}Total URLs:${reset} %s\n" "$total_urls"
    printf "  ${magenta}URL Limit:${reset}  %s\n" "$url_limit"
    echo ""
}

print_ulvis_info() {
    local response="$1"
    local identifier short_url long_url hits uses ads created_at last_access

    identifier="$(jq -r '.data.id // empty' <<<"$response" 2>/dev/null)"
    short_url="$(jq -r '.data.url // empty' <<<"$response" 2>/dev/null)"
    long_url="$(jq -r '.data.full // empty' <<<"$response" 2>/dev/null)"
    hits="$(jq -r '.data.hits // empty' <<<"$response" 2>/dev/null)"
    uses="$(jq -r '.data.uses // empty' <<<"$response" 2>/dev/null)"
    ads="$(jq -r '.data.ads // empty' <<<"$response" 2>/dev/null)"
    created_at="$(jq -r '.data.created // .data.date // empty' <<<"$response" 2>/dev/null)"
    last_access="$(jq -r '.data.last // empty' <<<"$response" 2>/dev/null)"

    if [[ -z "$short_url" && -n "$identifier" ]]; then
        short_url="https://ulvis.net/${identifier}"
    fi

    print_success "ulvis.net information:"
    printf "  ${magenta}ID:${reset}        %s\n" "$identifier"
    printf "  ${magenta}Short URL:${reset} %s\n" "${short_url:-n/a}"
    printf "  ${magenta}Long URL:${reset}  %s\n" "${long_url:-n/a}"
    printf "  ${magenta}Hits:${reset}      %s\n" "${hits:-0}"
    printf "  ${magenta}Uses Left:${reset} %s\n" "${uses:-unlimited}"
    printf "  ${magenta}Ads:${reset}       %s\n" "${ads:-n/a}"
    printf "  ${magenta}Created:${reset}   %s\n" "$(format_unix_timestamp "$created_at")"
    printf "  ${magenta}Last Seen:${reset} %s\n" "$(format_unix_timestamp "$last_access")"
    echo ""
}

tinyurl_menu() {
    local choice long_url custom_alias old_alias new_alias identifier response search_alias alias_filter count short_url

    ensure_tinyurl_config || return

    while true; do
        echo -e "${magenta}(*) TinyURL Selected${reset}\n(=) Choose an option:\n"
        echo -e "${cyan}1. Shorten a URL${reset}"
        echo -e "${cyan}2. Update an existing alias${reset}"
        echo -e "${cyan}3. Get TinyURL information${reset}"
        echo -e "${cyan}4. Get a list of TinyURLs${reset}"
        echo -e "${cyan}5. Get count of TinyURLs${reset}"
        echo -e "${cyan}6. Go back${reset}"
        echo -e "${cyan}7. Exit${reset}"
        echo ""

        read_with_quit choice "(->) Enter your selection (ex: 1): "
        echo ""

        case "$choice" in
            1)
                prompt_required_url long_url "(->) Enter the URL to shorten: "
                prompt_optional_alias custom_alias "(->) Custom alias (press enter to skip): " 30
                print_info "Shortening URL: ${long_url}"
                if short_url="$(tinyurl_shorten "$long_url" "$custom_alias")"; then
                    print_success "Shortened URL: ${short_url}"
                fi
                wait_for_input
                ;;
            2)
                prompt_required_alias old_alias "(->) Enter the alias you wish to update: " 30
                prompt_required_alias new_alias "(->) Enter the new alias: " 30
                print_info "Updating alias: ${old_alias} -> ${new_alias}"
                if short_url="$(tinyurl_update_alias "$old_alias" "$new_alias")"; then
                    print_success "Alias updated successfully: ${short_url}"
                fi
                wait_for_input
                ;;
            3)
                read_with_quit identifier "(->) Enter a TinyURL or alias: "
                identifier="$(trim "$identifier")"
                if [[ -z "$identifier" ]]; then
                    print_error "No TinyURL entered."
                else
                    print_info "Fetching TinyURL information..."
                    if response="$(tinyurl_lookup "$identifier")"; then
                        print_tinyurl_info "$response"
                    fi
                fi
                wait_for_input
                ;;
            4)
                read_with_quit search_alias "(->) Search for an alias (press enter to list all): "
                search_alias="$(trim "$search_alias")"
                if [[ -n "$search_alias" ]]; then
                    print_info "Searching for alias: ${search_alias}"
                else
                    print_info "Listing all TinyURLs..."
                fi
                if response="$(tinyurl_list "$search_alias")"; then
                    print_tinyurl_list "$response"
                fi
                wait_for_input
                ;;
            5)
                read_with_quit alias_filter "(->) Enter an alias to count (press enter for total count): "
                alias_filter="$(trim "$alias_filter")"
                if [[ -n "$alias_filter" ]]; then
                    print_info "Getting count for alias: ${alias_filter}"
                else
                    print_info "Getting total count of TinyURLs..."
                fi
                if count="$(tinyurl_count "$alias_filter")"; then
                    if [[ -n "$alias_filter" ]]; then
                        print_success "Count for alias ${alias_filter}: ${count}"
                    else
                        print_success "Total alias count: ${count}"
                    fi
                fi
                wait_for_input
                ;;
            6) return ;;
            7) safe_exit ;;
            *) print_error "Invalid option." ; wait_for_input ;;
        esac
    done
}

tinycc_menu() {
    local choice long_url custom_alias response search_term hash new_long_url new_alias short_url

    ensure_tinycc_config || return

    while true; do
        echo -e "${magenta}(*) Tiny.cc Selected${reset}\n(=) Choose an option:\n"
        echo -e "${cyan}1. Shorten a URL${reset}"
        echo -e "${cyan}2. Get a list of Tiny.cc URLs${reset}"
        echo -e "${cyan}3. Get account information${reset}"
        echo -e "${cyan}4. Edit a Tiny.cc URL${reset}"
        echo -e "${cyan}5. Go back${reset}"
        echo -e "${cyan}6. Exit${reset}"
        echo ""

        read_with_quit choice "(->) Enter your selection (ex: 1): "
        echo ""

        case "$choice" in
            1)
                prompt_required_url long_url "(->) Enter the URL to shorten: "
                prompt_optional_alias custom_alias "(->) Custom alias (press enter to skip): " 25
                print_info "Shortening URL: ${long_url}"
                if short_url="$(tinycc_shorten "$long_url" "$custom_alias")"; then
                    print_success "Shortened URL: ${short_url}"
                fi
                wait_for_input
                ;;
            2)
                read_with_quit search_term "(->) Enter a search term (press enter to list all): "
                search_term="$(trim "$search_term")"
                if [[ -n "$search_term" ]]; then
                    print_info "Searching Tiny.cc URLs for: ${search_term}"
                else
                    print_info "Listing all Tiny.cc URLs..."
                fi
                if response="$(tinycc_list "$search_term")"; then
                    print_tinycc_list "$response"
                fi
                wait_for_input
                ;;
            3)
                print_info "Fetching Tiny.cc account information..."
                if response="$(tinycc_account_info)"; then
                    print_tinycc_account_info "$response"
                fi
                wait_for_input
                ;;
            4)
                prompt_required_alias hash "(->) Enter the hash of the URL to edit: " 25
                prompt_required_url new_long_url "(->) Enter the new long URL: "
                prompt_optional_alias new_alias "(->) Enter the new custom alias (press enter to skip): " 25
                print_info "Updating Tiny.cc URL: ${hash}"
                if short_url="$(tinycc_edit "$hash" "$new_long_url" "$new_alias")"; then
                    print_success "URL updated successfully: ${short_url}"
                fi
                wait_for_input
                ;;
            5) return ;;
            6) safe_exit ;;
            *) print_error "Invalid option." ; wait_for_input ;;
        esac
    done
}

ulvis_menu() {
    local choice long_url custom_alias password uses expire identifier response short_url private_flag

    while true; do
        echo -e "${magenta}(*) ulvis.net Selected${reset}\n(=) Choose an option:\n"
        echo -e "${cyan}1. Shorten a URL${reset}"
        echo -e "${cyan}2. Get ulvis URL information${reset}"
        echo -e "${cyan}3. Go back${reset}"
        echo -e "${cyan}4. Exit${reset}"
        echo ""

        read_with_quit choice "(->) Enter your selection (ex: 1): "
        echo ""

        case "$choice" in
            1)
                prompt_required_url long_url "(->) Enter the URL to shorten: "
                prompt_optional_alias custom_alias "(->) Custom alias (press enter to skip): " 50
                if ask_yes_no "(->) Make this link private? (y/N): " "no"; then
                    private_flag="1"
                else
                    private_flag="0"
                fi
                prompt_optional_password password "(->) Password (press enter to skip): "
                prompt_optional_positive_integer uses "(->) Maximum uses (press enter to skip): "
                prompt_optional_expire_date expire "(->) Expiration date MM/DD/YYYY (press enter to skip): "
                print_info "Shortening URL with ulvis.net..."
                if short_url="$(ulvis_shorten "$long_url" "$custom_alias" "$private_flag" "$password" "$uses" "$expire")"; then
                    print_success "Shortened URL: ${short_url}"
                fi
                wait_for_input
                ;;
            2)
                read_with_quit identifier "(->) Enter a ulvis short code or full URL: "
                identifier="$(trim "$identifier")"
                if [[ -z "$identifier" ]]; then
                    print_error "No ulvis identifier entered."
                    wait_for_input
                    continue
                fi
                prompt_optional_password password "(->) Password (press enter to skip): "
                print_info "Fetching ulvis URL information..."
                if response="$(ulvis_lookup "$identifier" "$password")"; then
                    print_ulvis_info "$response"
                fi
                wait_for_input
                ;;
            3) return ;;
            4) safe_exit ;;
            *) print_error "Invalid option." ; wait_for_input ;;
        esac
    done
}

show_main_menu() {
    local choice

    while true; do
        show_banner
        echo -e "(=) Choose a service:\n"
        echo -e "${cyan}1. TinyURL${reset}"
        echo -e "${cyan}2. Tiny.cc${reset}"
        echo -e "${cyan}3. ulvis.net${reset}"
        echo -e "${cyan}4. Coming soon...${reset}"
        echo -e "${cyan}5. Exit${reset}"
        echo ""

        read_with_quit choice "(->) Enter your selection (ex: 1): "
        echo ""

        case "$choice" in
            1) tinyurl_menu ;;
            2) tinycc_menu ;;
            3) ulvis_menu ;;
            4) print_info "More services are still on the roadmap." ; wait_for_input ;;
            5) safe_exit ;;
            *) print_error "Invalid option." ; wait_for_input ;;
        esac
    done
}

normalize_service() {
    case "$(lowercase "$1")" in
        tinyurl) printf '%s' "tinyurl" ;;
        tinycc|tiny.cc) printf '%s' "tinycc" ;;
        ulvis|ulvis.net) printf '%s' "ulvis" ;;
        *) return 1 ;;
    esac
}

run_cli_mode() {
    local service="$1"
    local url="$2"
    local alias="$3"
    local lookup="$4"
    local private_flag="$5"
    local password="$6"
    local uses="$7"
    local expire="$8"
    local response short_url

    if [[ -n "$url" && -n "$lookup" ]]; then
        print_error "Use either --url or --lookup, not both."
        return 1
    fi

    if [[ -z "$url" && -z "$lookup" ]]; then
        print_error "CLI mode needs either --url or --lookup."
        return 1
    fi

    if [[ -n "$url" ]] && ! is_valid_url "$url"; then
        print_error "Invalid value passed to --url."
        return 1
    fi

    case "$service" in
        tinyurl)
            if [[ -n "$url" ]]; then
                short_url="$(tinyurl_shorten "$url" "$alias")" || return 1
                print_success "TinyURL: ${short_url}"
                return 0
            fi

            response="$(tinyurl_lookup "$lookup")" || return 1
            print_tinyurl_info "$response"
            ;;
        tinycc)
            if [[ -n "$lookup" ]]; then
                print_error "Tiny.cc CLI mode currently supports shortening only. Use interactive mode for listing and editing."
                return 1
            fi

            short_url="$(tinycc_shorten "$url" "$alias")" || return 1
            print_success "Tiny.cc URL: ${short_url}"
            ;;
        ulvis)
            if [[ -n "$url" ]]; then
                short_url="$(ulvis_shorten "$url" "$alias" "$private_flag" "$password" "$uses" "$expire")" || return 1
                print_success "ulvis.net URL: ${short_url}"
                return 0
            fi

            response="$(ulvis_lookup "$lookup" "$password")" || return 1
            print_ulvis_info "$response"
            ;;
        *)
            print_error "Unknown service."
            return 1
            ;;
    esac
}

parse_args() {
    cli_service=""
    cli_url=""
    cli_alias=""
    cli_lookup=""
    cli_private="0"
    cli_password=""
    cli_uses=""
    cli_expire=""

    while (( $# > 0 )); do
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                echo "${ver}"
                exit 0
                ;;
            --service)
                shift
                [[ -n "${1:-}" ]] || { print_error "--service needs a value."; exit 1; }
                cli_service="$(normalize_service "$1")" || { print_error "Unsupported service: $1"; exit 1; }
                ;;
            --url)
                shift
                [[ -n "${1:-}" ]] || { print_error "--url needs a value."; exit 1; }
                cli_url="$1"
                ;;
            --alias)
                shift
                [[ -n "${1:-}" ]] || { print_error "--alias needs a value."; exit 1; }
                cli_alias="$1"
                ;;
            --lookup)
                shift
                [[ -n "${1:-}" ]] || { print_error "--lookup needs a value."; exit 1; }
                cli_lookup="$1"
                ;;
            --private)
                cli_private="1"
                ;;
            --password)
                shift
                [[ -n "${1:-}" ]] || { print_error "--password needs a value."; exit 1; }
                cli_password="$1"
                ;;
            --uses)
                shift
                [[ -n "${1:-}" ]] || { print_error "--uses needs a value."; exit 1; }
                cli_uses="$1"
                ;;
            --expire)
                shift
                [[ -n "${1:-}" ]] || { print_error "--expire needs a value."; exit 1; }
                cli_expire="$1"
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
        shift
    done

    if [[ -n "$cli_alias" ]] && ! is_valid_alias "$cli_alias"; then
        print_error "Alias can only use letters, numbers, underscores, and hyphens."
        exit 1
    fi

    if [[ -n "$cli_password" ]] && (( ${#cli_password} > 10 )); then
        print_error "ulvis password must be 10 characters or fewer."
        exit 1
    fi

    if [[ -n "$cli_uses" ]] && ! is_valid_positive_integer "$cli_uses"; then
        print_error "--uses must be a positive whole number."
        exit 1
    fi

    if [[ -n "$cli_expire" ]] && ! is_valid_expire_date "$cli_expire"; then
        print_error "--expire must use MM/DD/YYYY."
        exit 1
    fi

    if [[ -z "$cli_service" ]] && [[ -n "$cli_url$cli_lookup$cli_alias$cli_password$cli_uses$cli_expire" || "$cli_private" == "1" ]]; then
        print_error "CLI options require --service."
        exit 1
    fi

    if [[ -n "$cli_service" && "$cli_service" != "ulvis" ]] && [[ -n "$cli_password$cli_uses$cli_expire" || "$cli_private" == "1" ]]; then
        print_error "--private, --password, --uses, and --expire are only supported with --service ulvis."
        exit 1
    fi
}

main() {
    parse_args "$@"
    load_env
    check_dependencies

    if [[ -n "$cli_service" ]]; then
        run_cli_mode \
            "$cli_service" \
            "$cli_url" \
            "$cli_alias" \
            "$cli_lookup" \
            "$cli_private" \
            "$cli_password" \
            "$cli_uses" \
            "$cli_expire"
        exit $?
    fi

    show_main_menu
}

main "$@"
