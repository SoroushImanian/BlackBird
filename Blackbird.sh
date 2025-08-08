#!/bin/bash
# SorBlack (Blackbird) FTP/X-UI Backup Script Installer (v2.1.0)

# This script automatically fetches user configuration files from a list of URLs,
# saves them locally, and uploads them to a secure FTP (FTPS) server.
# It is designed to be run periodically via a cron job and is managed by the
# accompanying 'Blackbird.sh' script.

set -e

NC='\033[0m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'

# --- Dynamic Paths and Variables ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CRED_DIR="$SCRIPT_DIR/.credentials"
KEY_FILE_PATH="$CRED_DIR/secret.key"
ENCRYPTED_ENV_FILE_PATH="$CRED_DIR/.env.encrypted"
SUBSCRIPTION_CONFIG_FILE="$CRED_DIR/subscription.conf"

PYTHON_SCRIPT_PATH="$SCRIPT_DIR/helper.py"
LOG_FILE_PATH="$SCRIPT_DIR/cron_log.txt"
USERS_FILE_PATH="$SCRIPT_DIR/users.txt"
DISABLED_USERS_FILE="$SCRIPT_DIR/disabled_users.txt"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"

RUN_COMMAND="/usr/bin/python3 $PYTHON_SCRIPT_PATH >> $LOG_FILE_PATH 2>&1"
CRON_JOB="0 */4 * * * $RUN_COMMAND"

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"

     ███████╗ ██████╗ ██████╗  ████████╗ ██╗     ██████╗      ██████╗██╗  ██╗
     ██╔════╝██╔═══██╗██╔══██╗ ██╔══ ██╗ ██║     ██╔═══██╗   ██╔════╝██║ ██╔╝
     ███████╗██║   ██║██████╔╝ ██║███ ██║██║     ██║   ██║   ██║     █████╔╝
     ╚════██║██║   ██║██╔══██╗ ██║   ██║ ██║     ██║   ██    ██║     ██╔═██╗
     ███████║╚██████╔╝██║  ██║╚████████╔╝███████╗╚██████╔███ ╚██████╗██║  ██╗
     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝   ╚══════╝╚═════╝ ╚═════╝╚═╝ ╚═╝   ╚═╝

EOF
    echo -e "${RED}     ============================================================================${NC}"
    echo -e "${YELLOW}                              🐦 Blackbird Script${NC}"
    echo -e "${YELLOW}                                      v2.1.0${NC}"
    echo -e "${RED}     ============================================================================${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${YELLOW}                                   SorBlack.com${NC}"
    echo -e "${YELLOW}                              No Body Can limit me ...${NC}"
    echo -e "${YELLOW}                                  tel: @sorblack${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo
}

format_time() {
    local T=$1
    local D=$((T / 60 / 60 / 24))
    local H=$((T / 60 / 60 % 24))
    local M=$((T / 60 % 60))
    local S=$((T % 60))
    local parts=()
    ((D > 0)) && parts+=("${D}d")
    ((H > 0)) && parts+=("${H}h")
    ((M > 0)) && parts+=("${M}m")
    ((S > 0)) && parts+=("${S}s")
    local IFS=,
    echo "${parts[*]}"
}

parse_cron_interval() {
    local cron_job_line="$1"
    local min=$(echo "$cron_job_line" | awk '{print $1}')
    local hour=$(echo "$cron_job_line" | awk '{print $2}')
    local day_of_month=$(echo "$cron_job_line" | awk '{print $3}')

    if [[ "$min" == "*/"* ]]; then
        echo "Every ${min#\*/} Minutes"
    elif [[ "$hour" == "*/"* ]]; then
        echo "Every ${hour#\*/} Hours"
    elif [[ "$day_of_month" == "*/"* ]]; then
        echo "Every ${day_of_month#\*/} Days"
    elif [[ "$hour" == "*" ]]; then
        echo "Every Hour"
    elif [[ "$min" == "0" && "$hour" == "0" ]]; then
        echo "Every Day"
    else
        echo "Custom Schedule"
    fi
}

check_status() {
    show_banner
    echo -e "${BOLD}${CYAN}## SCRIPT STATUS REPORT ##${NC}"
    echo -e "${GREEN}--------------------------------------------------${NC}"

    echo -n -e "${BOLD}Cron Job Status: ${NC}"
    local cron_job_found=$(crontab -l 2>/dev/null | grep -F "$PYTHON_SCRIPT_PATH" || true)
    if [ -n "$cron_job_found" ]; then
        echo -e "${GREEN}[ACTIVE]${NC}"
        echo -e "   ${YELLOW}Found Job:${NC} ${cron_job_found}"
        local human_readable_interval=$(parse_cron_interval "$cron_job_found")
        echo -e "   ${YELLOW}Execution Interval:${NC} ${BOLD}${human_readable_interval}${NC}"
    else
        echo -e "${RED}[INACTIVE]${NC}"
        echo -e "   ${YELLOW}Execution Interval:${NC} - Not Set -"
    fi
    echo -e "${GREEN}--------------------------------------------------${NC}"

    echo -e "${BOLD}Current Subscription Settings:${NC}"
    if [ -f "$SUBSCRIPTION_CONFIG_FILE" ]; then
        source "$SUBSCRIPTION_CONFIG_FILE"
        echo -e "  ${BOLD}Domain/IP:${NC} ${XUI_HOST}"
        echo -e "  ${BOLD}Port:${NC} ${XUI_PORT}"
        echo -e "  ${BOLD}Path:${NC} /${XUI_PATH}/"
        echo -e "  ${BOLD}Base URL:${NC} ${BASE_URL}"
    else
        echo -e "  ${YELLOW}Not configured yet. Please install the script first.${NC}"
    fi
    echo -e "${GREEN}--------------------------------------------------${NC}"

    if [ ! -f "$LOG_FILE_PATH" ]; then
        echo -e "${YELLOW}Log file not found. Run the script at least once.${NC}"
        echo -e "${GREEN}--------------------------------------------------${NC}"
        return
    fi

    echo -e "${BOLD}Analysis of Last Run:${NC}"
    local last_start_line_num=$(grep -n -e "--- Starting Script ---" "$LOG_FILE_PATH" | tail -1 | cut -d: -f1 || true)
    
    if [ -z "$last_start_line_num" ]; then
        echo -e "${YELLOW}No complete run found in log file.${NC}"
        echo -e "${GREEN}--------------------------------------------------${NC}"
        return
    fi
    
    local last_log_block=$(tail -n +$last_start_line_num "$LOG_FILE_PATH")
    local last_run_timestamp_str=$(echo "$last_log_block" | grep "Script started at:" | head -1 | sed 's/Script started at: //')
    
    if [ -z "$last_run_timestamp_str" ]; then
        echo -e "${YELLOW}Could not determine last run time from log.${NC}"
        echo -e "${GREEN}--------------------------------------------------${NC}"
        return
    fi

    echo -e "  ${BOLD}Last execution time:${NC} ${YELLOW}$last_run_timestamp_str${NC}"

    echo -n "  1. Was FTP upload successful? ................ "
    if echo "$last_log_block" | grep -q "All files uploaded successfully."; then
        echo -e "${GREEN}Yes${NC}"
    else
        echo -e "${RED}No or Not Attempted${NC}"
    fi

    local processed_users=$(echo "$last_log_block" | grep -c "Processing user:")
    local failed_configs=$(echo "$last_log_block" | grep -c "Failed to retrieve config")
    echo -e "  2. Were user files created? ................ ${BOLD}$processed_users Processed, $failed_configs Failures${NC}"

    echo -e "${GREEN}--------------------------------------------------${NC}"
    echo -e "${BOLD}Overall Statistics:${NC}"
    local total_runs=$(grep -c -e "--- Starting Script ---" "$LOG_FILE_PATH" || true)
    echo -e "  3. Total script runs so far: ................ ${BOLD}$total_runs${NC}"
    local ftp_failures=$(grep -c "Failed to upload files to FTP" "$LOG_FILE_PATH" || true)
    echo -e "  4. Total FTP upload failures: ................ ${BOLD}${RED}$ftp_failures${NC}"

    if [ -n "$last_run_timestamp_str" ] && [ -n "$cron_job_found" ]; then
        local parsable_date=$(echo "$last_run_timestamp_str" | sed 's/ - / /')
        local last_run_epoch=$(date -d "$parsable_date" +%s)
        
        local min_part=$(echo "$cron_job_found" | awk '{print $1}')
        local hour_part=$(echo "$cron_job_found" | awk '{print $2}')
        local day_part=$(echo "$cron_job_found" | awk '{print $3}')
        
        local interval_seconds=0
        if [[ "$min_part" == "*/"* ]]; then interval_seconds=$((${min_part#\*/}*60)); fi
        if [[ "$hour_part" == "*/"* ]]; then interval_seconds=$((${hour_part#\*/}*3600)); fi
        if [[ "$day_part" == "*/"* ]]; then interval_seconds=$((${day_part#\*/}*86400)); fi
        if [[ "$hour_part" == "*" ]] && [[ "$min_part" != "*/"* ]]; then interval_seconds=3600; fi
        if [[ "$min_part" == "0" && "$hour_part" == "0" && "$day_part" == "*" ]]; then interval_seconds=86400; fi
        if [[ $interval_seconds -eq 0 ]]; then interval_seconds=$((4*3600)); fi

        local next_run_epoch=$((last_run_epoch + interval_seconds))
        local current_epoch=$(date +%s)
        local seconds_remaining=$((next_run_epoch - current_epoch))

        if [ $seconds_remaining -gt 0 ]; then
            local time_remaining_str=$(format_time $seconds_remaining)
            echo -e "  5. Time until next automatic run: ............ ${BOLD}${CYAN}$time_remaining_str${NC}"
        else
            echo -e "  5. Time until next automatic run: ............ ${BOLD}${YELLOW}Overdue, should run soon.${NC}"
        fi
    fi
    echo -e "${GREEN}--------------------------------------------------${NC}"
}

update_cron_job() {
    local new_cron_time=$1
    local new_cron_job="$new_cron_time $RUN_COMMAND"
    (crontab -l 2>/dev/null | grep -vF "$PYTHON_SCRIPT_PATH"; echo "$new_cron_job") | crontab -
    echo -e "\n${GREEN}Cron job updated successfully!${NC}"
    echo -e "New schedule: ${YELLOW}${new_cron_job}${NC}"
}

handle_custom_time() {
    local hours minutes total_minutes cron_string
    read -p "Enter interval hours (0-23): " hours
    read -p "Enter interval minutes (0-59): " minutes

    if ! [[ "$hours" =~ ^[0-9]+$ ]] || ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid input. Please enter numbers only.${NC}"; return
    fi

    total_minutes=$((hours * 60 + minutes))

    if (( total_minutes == 0 )); then
        echo -e "${RED}Interval cannot be zero.${NC}"; return
    elif (( total_minutes < 60 && 60 % total_minutes == 0 )); then
        cron_string="*/$total_minutes * * * *"
    elif (( total_minutes >= 60 && total_minutes % 60 == 0 )); then
        hours=$((total_minutes / 60))
        if (( hours < 24 && 24 % hours == 0 )); then
            cron_string="0 */$hours * * *"
        elif (( hours >= 24 && hours % 24 == 0 )); then
            days=$((hours / 24))
            cron_string="0 0 */$days * *"
        else
            cron_string=""
        fi
    else
        cron_string=""
    fi

    if [ -n "$cron_string" ]; then
        update_cron_job "$cron_string"
    else
        echo -e "\n${RED}Error: The custom interval ($hours h, $minutes m) cannot be set with a simple cron schedule.${NC}"
        echo -e "${YELLOW}Please choose one of the standard options or a simpler interval (e.g., 30m, 2h, 1d).${NC}"
    fi
}

change_cron_time() {
    show_banner
    echo -e "${BOLD}${CYAN}## CHANGE CRON SCHEDULE ##${NC}\n"
    
    if ! crontab -l 2>/dev/null | grep -Fq "$PYTHON_SCRIPT_PATH"; then
        echo -e "${RED}Error: Cron job not found. Please install the script first (Option 1).${NC}"
        return
    fi
    
    CURRENT_CRON_JOB=$(crontab -l | grep -F "$PYTHON_SCRIPT_PATH")
    echo -e "The current schedule is set to:\n${YELLOW}${CURRENT_CRON_JOB}${NC}\n"
    
    echo -e "Please select a new schedule from the options below:"
    echo -e "  ${CYAN}1)${NC} Every 15 Minutes"
    echo -e "  ${CYAN}2)${NC} Every 30 Minutes"
    echo -e "  ${CYAN}3)${NC} Every Hour"
    echo -e "  ${CYAN}4)${NC} Every 4 Hours ${YELLOW}(Default)${NC}"
    echo -e "  ${CYAN}5)${NC} Every 12 Hours"
    echo -e "  ${CYAN}6)${NC} Every Day (at midnight)"
    echo -e "  ${CYAN}7)${NC} Custom Schedule..."
    echo -e "  ${CYAN}8)${NC} Back to Main Menu"
    echo
    read -p "Enter your choice [1-8]: " schedule_choice

    case $schedule_choice in
        1) update_cron_job "*/15 * * * *";;
        2) update_cron_job "*/30 * * * *";;
        3) update_cron_job "0 * * * *";;
        4) update_cron_job "0 */4 * * *";;
        5) update_cron_job "0 */12 * * *";;
        6) update_cron_job "0 0 * * *";;
        7) handle_custom_time;;
        8) return;;
        *) echo -e "${RED}Invalid option.${NC}"; return;;
    esac
}

check_and_install_python() {
    if ! command -v python3 &>/dev/null; then
        echo -e "${YELLOW}Python 3 is not installed, which is required.${NC}"
        read -p "Do you want to install it now? (y/n): " choice
        case "$choice" in
        y | Y)
            echo "Installing Python 3..."
            sudo apt-get update
            sudo apt-get install -y python3
            echo -e "${GREEN}Python 3 installed successfully.${NC}"
            ;;
        *)
            echo -e "${RED}Installation cancelled by user.${NC}"
            exit 1
            ;;
        esac
    fi
}

encrypt_and_save_credentials() {
    export SB_KEY_PATH="$1"
    export SB_ENC_PATH="$2"
    export SB_ENV_CONTENT="$3"
    
    python3 -c '
import sys, os
from cryptography.fernet import Fernet

key_path = os.getenv("SB_KEY_PATH")
encrypted_path = os.getenv("SB_ENC_PATH")
env_content = os.getenv("SB_ENV_CONTENT")

try:
    if os.path.exists(key_path):
        with open(key_path, "rb") as f: key = f.read()
    else:
        key = Fernet.generate_key()
        with open(key_path, "wb") as f: f.write(key)
    
    fernet = Fernet(key)
    encrypted_data = fernet.encrypt(env_content.encode("utf-8"))
    
    with open(encrypted_path, "wb") as f: f.write(encrypted_data)
    
except Exception as e:
    print(f"Python Error: {e}", file=sys.stderr)
    sys.exit(1)
'
}

setup_credentials() {
    local old_host="$1"
    local old_user="$2"
    local old_pass_placeholder="$3"
    local old_port="$4"
    
    local new_host new_user new_pass new_port

    echo -e "${YELLOW}At any prompt, you can enter 'm' to cancel and return to the main menu.${NC}"

    if [ -n "$old_host" ]; then
        read -p "Enter FTP Host (or press Enter to keep '$old_host'): " new_host
        if [[ "${new_host,,}" == "m" ]]; then return 1; fi
        new_host=${new_host:-$old_host}
    else
        read -p "Enter FTP Host: " new_host
        if [[ "${new_host,,}" == "m" ]]; then return 1; fi
    fi

    if [ -n "$old_user" ]; then
        read -p "Enter FTP User (or press Enter to keep '$old_user'): " new_user
        if [[ "${new_user,,}" == "m" ]]; then return 1; fi
        new_user=${new_user:-$old_user}
    else
        read -p "Enter FTP User: " new_user
        if [[ "${new_user,,}" == "m" ]]; then return 1; fi
    fi

    if [ -n "$old_pass_placeholder" ]; then
        read -s -p "Enter FTP Password (or press Enter to keep the current one): " new_pass
        echo
        if [[ "${new_pass,,}" == "m" ]]; then return 1; fi
    else
        read -s -p "Enter FTP Password: " new_pass
        echo
        if [[ "${new_pass,,}" == "m" ]]; then return 1; fi
    fi

    if [ -n "$old_port" ]; then
        read -p "Enter FTP Port (optional, press Enter for default '$old_port'): " new_port
        if [[ "${new_port,,}" == "m" ]]; then return 1; fi
        new_port=${new_port:-$old_port}
    else
        read -p "Enter FTP Port (optional, press Enter for default '21'): " new_port
        if [[ "${new_port,,}" == "m" ]]; then return 1; fi
        new_port=${new_port:-21}
    fi

    if [ -z "$new_host" ] || [ -z "$new_user" ]; then
        echo -e "${RED}Error: Host and User cannot be empty.${NC}"; return 1
    fi
    
    if [ -z "$new_pass" ] && [ -n "$old_pass_placeholder" ]; then
        export SB_KEY_PATH="$KEY_FILE_PATH"
        export SB_ENC_PATH="$ENCRYPTED_ENV_FILE_PATH"
        decrypted_content=$(python3 -c '
import sys, os
from cryptography.fernet import Fernet
try:
    with open(os.getenv("SB_KEY_PATH"), "rb") as f: key = f.read()
    fernet = Fernet(key)
    with open(os.getenv("SB_ENC_PATH"), "rb") as f: encrypted = f.read()
    print(fernet.decrypt(encrypted).decode("utf-8"))
except:
    sys.exit(1)
')
        new_pass=$(echo -e "$decrypted_content" | grep "^FTP_PASS=" | cut -d'=' -f2 | tr -d '\r')
    elif [ -z "$new_pass" ]; then
        echo -e "${RED}Error: Password cannot be empty for a new setup.${NC}"; return 1
    fi
    
    mkdir -p "$CRED_DIR"
    local env_data
    env_data=$(printf "FTP_HOST=%s\nFTP_USER=%s\nFTP_PASS=%s\nFTP_PORT=%s" "$new_host" "$new_user" "$new_pass" "$new_port")
    
    encrypt_and_save_credentials "$KEY_FILE_PATH" "$ENCRYPTED_ENV_FILE_PATH" "$env_data"
    
    chmod 600 "$KEY_FILE_PATH"
    chmod 600 "$ENCRYPTED_ENV_FILE_PATH"
    echo -e "\n${GREEN}Credentials have been securely encrypted and saved.${NC}"
    return 0
}

change_credentials() {
    show_banner
    echo -e "${BOLD}${CYAN}## CHANGE FTP CREDENTIALS ##${NC}\n"
    
    if [ ! -f "$ENCRYPTED_ENV_FILE_PATH" ]; then
        echo -e "${RED}Error: No credentials found. Please install the script first (Option 1).${NC}"
        return
    fi
    
    export SB_KEY_PATH="$KEY_FILE_PATH"
    export SB_ENC_PATH="$ENCRYPTED_ENV_FILE_PATH"
    local decrypted_content
    decrypted_content=$(python3 -c '
import sys, os
from cryptography.fernet import Fernet
try:
    with open(os.getenv("SB_KEY_PATH"), "rb") as f: key = f.read()
    fernet = Fernet(key)
    with open(os.getenv("SB_ENC_PATH"), "rb") as f: encrypted = f.read()
    print(fernet.decrypt(encrypted).decode("utf-8"))
except Exception:
    sys.exit(1)
')
    
    if [ -z "$decrypted_content" ]; then
        echo -e "${RED}Error: Failed to decrypt existing credentials. The key file might be missing or corrupt.${NC}"
        return
    fi

    local current_host=""
    local current_user=""
    local current_port=""
    
    while IFS='=' read -r key value; do
        case "$key" in
            FTP_HOST) current_host=$(echo "$value" | tr -d '\r') ;;
            FTP_USER) current_user=$(echo "$value" | tr -d '\r') ;;
            FTP_PORT) current_port=$(echo "$value" | tr -d '\r') ;;
        esac
    done <<< "$decrypted_content"
    
    if ! setup_credentials "$current_host" "$current_user" "********" "$current_port"; then
        echo -e "\n${GREEN}Operation cancelled. Returning to main menu.${NC}"
    fi
}

#================================================================
# USER MANAGEMENT FUNCTIONS (REVISED)
#================================================================

get_username_from_link() {
    local link="$1"
    basename "$link"
}

display_and_get_choice() {
    local file_path="$1"
    
    touch "$file_path"
    mapfile -t links < <(tr -d '\r' < "$file_path")
    
    # Filter out empty lines from the array
    local valid_links=()
    for link in "${links[@]}"; do
        if [ -n "$link" ]; then
            valid_links+=("$link")
        fi
    done

    if [ ${#valid_links[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}The list is currently empty.${NC}" >&2
        return 1
    fi
    
    local i=1
    for link in "${valid_links[@]}"; do
        local username=$(get_username_from_link "$link")
        echo -e "  ${CYAN}${i})${NC} $username"
        ((i++))
    done
    
    echo
    read -p "Enter the number of the user (or 'm' to return to menu): " choice
    
    if [[ "${choice,,}" == "m" ]]; then return 1; fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#valid_links[@]} ]; then
        echo -e "${RED}Invalid selection.${NC}" >&2
        return 1
    fi
    
    echo "${valid_links[$((choice-1))]}" # Return the chosen link
    return 0
}

read_input() {
    read -p "$1" "$2" < /dev/tty
}

add_user() {
    set +e
    source "$SUBSCRIPTION_CONFIG_FILE"
    if [ -z "$BASE_URL" ]; then
        echo -e "${RED}Error: BASE_URL is not set. Please use the 'Change Subscription Settings' menu.${NC}"
        read_input "Press [Enter] to return..." dummy
        return
    fi
    
    while true; do
        show_banner
        echo -e "${BOLD}${CYAN}## ADD NEW USER(S) ##${NC}"
	echo -e
	echo -e "${YELLOW}Enter username :${NC}\n"
	echo -e "${YELLOW}- Enter username(s) separated by a comma (,) (Optional)${NC}\n"
        echo -e "${YELLOW}- Press [Enter] on an empty line to return.${NC}\n"

        read_input "Enter username(s): " user_input
        
        if [ -z "$user_input" ]; then break; fi

        local user_list_string=${user_input//,/ }
        local added_count=0
        local skipped_count=0
        
        for username in $user_list_string; do
            username=$(echo "$username" | xargs)
            if [ -z "$username" ]; then continue; fi

            local new_link="${BASE_URL}${username}"
            
            touch "$USERS_FILE_PATH" "$DISABLED_USERS_FILE"
            if grep -qF -- "$new_link" "$USERS_FILE_PATH" || grep -qF -- "$new_link" "$DISABLED_USERS_FILE"; then
                echo -e "${YELLOW}  -> Skipping '$username': User already exists.${NC}"
                ((skipped_count++))
            else
                echo "$new_link" >> "$USERS_FILE_PATH"
                echo -e "${GREEN}  -> User '$username' added successfully.${NC}"
                ((added_count++))
            fi
        done
        
        echo -e "\n${BOLD}Summary:${NC} ${GREEN}${added_count} added${NC}, ${YELLOW}${skipped_count} skipped${NC}."
        sleep 2
    done
    set -e
}

delete_user() {
    while true; do
        show_banner
        echo -e "${BOLD}${CYAN}## DELETE USER ##${NC}"
        
        touch "$USERS_FILE_PATH"
        mapfile -t links_raw < <(tr -d '\r' < "$USERS_FILE_PATH")
        local links=(); for link in "${links_raw[@]}"; do [ -n "$link" ] && links+=("$link"); done

        if [ ${#links[@]} -eq 0 ]; then
            echo -e "\n${YELLOW}The list of active users is currently empty.${NC}"
            return
        fi

        echo -e "\nSelect an ACTIVE user to permanently delete:"
        local i=1
        for link in "${links[@]}"; do
            local username=$(get_username_from_link "$link")
            echo -e "  ${CYAN}${i})${NC} $username"; ((i++))
        done
        
        echo
        read_input "Enter the number of the user (or press Enter to return): " choice
        
        if [ -z "$choice" ]; then break; fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#links[@]} ]; then
            echo -e "${RED}Invalid selection. Please try again.${NC}"; sleep 2; continue
        fi
        
        local index_to_delete=$((choice - 1))
        local username=$(get_username_from_link "${links[$index_to_delete]}")
        
        read_input "Are you sure you want to permanently delete user '$username'? (y/n): " confirm
        if [[ "${confirm,,}" == "y" ]]; then
            unset 'links[$index_to_delete]'
            printf "%s\n" "${links[@]}" > "$USERS_FILE_PATH"
            echo -e "${GREEN}User '$username' deleted successfully.${NC}"
        else
            echo "Deletion cancelled."
        fi
        sleep 1
    done
}

disable_user() {
    while true; do
        show_banner
        echo -e "${BOLD}${CYAN}## DISABLE USER ##${NC}"
        
        touch "$USERS_FILE_PATH"
        mapfile -t links_raw < <(tr -d '\r' < "$USERS_FILE_PATH")
        local links=(); for link in "${links_raw[@]}"; do [ -n "$link" ] && links+=("$link"); done

        if [ ${#links[@]} -eq 0 ]; then
            echo -e "\n${YELLOW}The list of active users is currently empty.${NC}"; return
        fi

        echo -e "\nSelect an ACTIVE user to disable:"
        local i=1
        for link in "${links[@]}"; do
            local username=$(get_username_from_link "$link")
            echo -e "  ${CYAN}${i})${NC} $username"; ((i++))
        done

        echo
        read_input "Enter the number of the user (or press Enter to return): " choice

        if [ -z "$choice" ]; then break; fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#links[@]} ]; then
            echo -e "${RED}Invalid selection. Please try again.${NC}"; sleep 2; continue
        fi

        local index_to_disable=$((choice - 1))
        local link_to_disable="${links[$index_to_disable]}"
        local username=$(get_username_from_link "$link_to_disable")

        read_input "Are you sure you want to disable user '$username'? (y/n): " confirm
        if [[ "${confirm,,}" == "y" ]]; then
            if ! grep -qF -- "$link_to_disable" "$DISABLED_USERS_FILE"; then
                echo "$link_to_disable" >> "$DISABLED_USERS_FILE"
            fi
            unset 'links[$index_to_disable]'
            printf "%s\n" "${links[@]}" > "$USERS_FILE_PATH"
            echo -e "${GREEN}User '$username' has been disabled.${NC}"
        else
            echo "Disabling cancelled."
        fi
        sleep 1
    done
}

enable_user() {
    while true; do
        show_banner
        echo -e "${BOLD}${CYAN}## ENABLE USER ##${NC}"
        
        touch "$DISABLED_USERS_FILE"
        mapfile -t links_raw < <(tr -d '\r' < "$DISABLED_USERS_FILE")
        local links=(); for link in "${links_raw[@]}"; do [ -n "$link" ] && links+=("$link"); done

        if [ ${#links[@]} -eq 0 ]; then
            echo -e "\n${YELLOW}The list of disabled users is currently empty.${NC}"; return
        fi

        echo -e "\nSelect a DISABLED user to enable:"
        local i=1
        for link in "${links[@]}"; do
            local username=$(get_username_from_link "$link")
            echo -e "  ${CYAN}${i})${NC} $username"; ((i++))
        done

        echo
        read_input "Enter the number of the user (or press Enter to return): " choice

        if [ -z "$choice" ]; then break; fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#links[@]} ]; then
            echo -e "${RED}Invalid selection. Please try again.${NC}"; sleep 2; continue
        fi
        
        local index_to_enable=$((choice - 1))
        local link_to_enable="${links[$index_to_enable]}"
        local username=$(get_username_from_link "$link_to_enable")

        read_input "Are you sure you want to enable user '$username'? (y/n): " confirm
        if [[ "${confirm,,}" == "y" ]]; then
            if ! grep -qF -- "$link_to_enable" "$USERS_FILE_PATH"; then
                echo "$link_to_enable" >> "$USERS_FILE_PATH"
            fi
            unset 'links[$index_to_enable]'
            printf "%s\n" "${links[@]}" > "$DISABLED_USERS_FILE"
            echo -e "${GREEN}User '$username' has been enabled successfully.${NC}"
        else
            echo "Enabling cancelled."
        fi
        sleep 1
    done
}

view_user_status() {
    show_banner
    echo -e "\n${BOLD}${CYAN}## USER STATUS LIST ##${NC}\n"
    touch "$USERS_FILE_PATH" "$DISABLED_USERS_FILE"
    
    mapfile -t active_links < <(tr -d '\r' < "$USERS_FILE_PATH")
    mapfile -t disabled_links < <(tr -d '\r' < "$DISABLED_USERS_FILE")
    
    if [ ${#active_links[@]} -eq 0 ] && [ ${#disabled_links[@]} -eq 0 ]; then
        echo -e "${YELLOW}No users found.${NC}"
    else
        local i=1
        for link in "${active_links[@]}"; do
            if [ -n "$link" ]; then
                local username=$(get_username_from_link "$link")
                echo -e "  ${BOLD}${i})${NC} $username - ${GREEN}[Active]${NC}"
                ((i++))
            fi
        done
        
        for link in "${disabled_links[@]}"; do
            if [ -n "$link" ]; then
                local username=$(get_username_from_link "$link")
                echo -e "  ${BOLD}${i})${NC} $username - ${RED}[Disabled]${NC}"
                ((i++))
            fi
        done
    fi
    echo 
}

user_management_menu() {
    while true; do
        show_banner
        echo -e "${BOLD}${CYAN}## USER MANAGEMENT ##${NC}"
        echo -e "Please choose an option:"
        echo -e "  ${CYAN}1)${NC} Add User"
        echo -e "  ${CYAN}2)${NC} Delete User"
        echo -e "  ${CYAN}3)${NC} Disable User"
        echo -e "  ${CYAN}4)${NC} Enable User"
        echo -e "  ${CYAN}5)${NC} View User Status"
        echo -e "  ${CYAN}6)${NC} Back to Main Menu"
        echo
        read -p "Enter your choice [1-6]: " choice
        
        case $choice in
            1)
                add_user
                read -p "Press [Enter] to return to the User Management menu..."
                ;;
            2)
                delete_user
                read -p "Press [Enter] to return to the User Management menu..."
                ;;
            3)
                disable_user
                read -p "Press [Enter] to return to the User Management menu..."
                ;;
            4)
                enable_user
                read -p "Press [Enter] to return to the User Management menu..."
                ;;
            5)
                view_user_status
                read -p "Press [Enter] to return to the User Management menu..."
                ;;
            6)
                return
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

get_public_ip() {
    hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1"
}

check_nc() {
    if ! command -v nc &>/dev/null; then
        echo -e "${YELLOW}Netcat (nc) is not installed. Attempting to install...${NC}"
        sudo apt-get update >/dev/null && sudo apt-get install -y netcat-traditional >/dev/null
    fi
}

validate_connection() {
    local host="$1"
    local port="$2"
    check_nc
    echo -e "\n${YELLOW}Testing connection to ${host}:${port}...${NC}"
    if nc -zv "$host" "$port" &>/dev/null; then
        echo -e "${GREEN}Connection successful!${NC}"
        return 0
    else
        echo -e "${RED}Connection failed. The host or port may be incorrect or blocked.${NC}"
        return 1
    fi
}

build_users_file() {
    local base_url="$1"
    
    touch "$USERS_FILE_PATH"
    mapfile -t current_links < <(tr -d '\r' < "$USERS_FILE_PATH")
    
    > "$USERS_FILE_PATH" 
    for link in "${current_links[@]}"; do
        if [ -n "$link" ]; then
            local username=$(basename "$link")
            echo "${base_url}${username}" >> "$USERS_FILE_PATH"
        fi
    done
    echo -e "${GREEN}'users.txt' file has been updated with the new subscription base URL.${NC}"
}

#================================================================
# SUBSCRIPTION AND CREDENTIALS SETUP WIZARD
#================================================================

gather_subscription_info() {
    local current_domain="$1"
    local current_port="$2"
    local current_path="$3"
    
    local base_url=""
    
    while true; do
        local xui_host xui_port xui_path pure_host final_host_part

        if [ -z "$current_domain" ]; then
            read -p "Is your X-UI panel on this server? (y/n): " is_local
            if [[ "${is_local,,}" == "y" ]]; then
                xui_host="http://127.0.0.1"
            else
                read -p "Auto-detect this server's public IP? (Y/n): " auto_ip
                if [[ "${auto_ip,,}" == "n" ]]; then
                    read -p "Enter the full IP or Domain (e.g., http://my.domain.com or https://1.2.3.4): " xui_host
                else
                    xui_host=$(get_public_ip)
                fi
            fi
            read -p "Enter the subscription port (default: 2096): " xui_port
            xui_port=${xui_port:-2096}
            
            read -p "Enter the subscription path without slashes (default: sub): " xui_path
            xui_path=${xui_path:-sub}
        else
            read -p "Enter new IP or Domain (or press Enter to keep '$current_domain'): " xui_host
            xui_host=${xui_host:-$current_domain}
            read -p "Enter new Port (or press Enter to keep '$current_port'): " xui_port
            xui_port=${xui_port:-$current_port}
            read -p "Enter new Path (or press Enter to keep '$current_path'): " xui_path
            xui_path=${xui_path:-$current_path}
        fi
        
        final_host_part="$xui_host"
        if [[ "$final_host_part" != *"http"* ]]; then
             final_host_part="http://${final_host_part}"
        fi
        
        pure_host=$(echo "$final_host_part" | sed -e 's#^http[s]*://##' -e 's#/$##')
        
        if validate_connection "$pure_host" "$xui_port"; then
            base_url="${final_host_part}:${xui_port}/${xui_path}/"
            break
        else
            read -p "Do you want to re-enter the IP/Domain and Port? (y/n): " retry
            if [[ "${retry,,}" != "y" ]]; then
                echo -e "${YELLOW}Proceeding with the provided settings despite connection failure.${NC}"
                base_url="${final_host_part}:${xui_port}/${xui_path}/"
                break
            fi
        fi
    done
    
    echo -e "\n${GREEN}--- Subscription Settings Summary ---${NC}"
    echo -e "  ${BOLD}Domain/IP:${NC} ${pure_host}"
    echo -e "  ${BOLD}Port:${NC} ${xui_port}"
    echo -e "  ${BOLD}Path:${NC} /${xui_path}/"
    echo -e "  ${BOLD}Final Base URL:${NC} ${base_url}"
    echo -e "${GREEN}-------------------------------------${NC}"
    
    mkdir -p "$CRED_DIR"
    printf "XUI_HOST=%s\nXUI_PORT=%s\nXUI_PATH=%s\nBASE_URL=%s\n" "$pure_host" "$xui_port" "$xui_path" "$base_url" > "$SUBSCRIPTION_CONFIG_FILE"
}

change_subscription_settings() {
    show_banner
    echo -e "${BOLD}${CYAN}## CHANGE SUBSCRIPTION SETTINGS ##${NC}\n"
    
    if [ ! -f "$SUBSCRIPTION_CONFIG_FILE" ]; then
        echo -e "${RED}Error: Script is not installed yet. Please use Option 1 first.${NC}"
        return
    fi
    
    source "$SUBSCRIPTION_CONFIG_FILE"
    
    gather_subscription_info "$XUI_HOST" "$XUI_PORT" "$XUI_PATH"
    
    source "$SUBSCRIPTION_CONFIG_FILE" # Re-source to get the new BASE_URL
    build_users_file "$BASE_URL"
}

install_script() {
    if crontab -l 2>/dev/null | grep -Fq "$PYTHON_SCRIPT_PATH"; then
        echo -e "${YELLOW}Warning: The script seems to be already installed.${NC}"
        read -p "Do you want to proceed with re-installation? This will overwrite ALL settings. (y/n): " choice
        if [[ "${choice,,}" != "y" ]]; then
            echo "Re-installation cancelled."
            return
        fi
    fi
    
    echo "Starting the installation process..."
    check_and_install_python
    
    echo -e "\n${BOLD}--- Step 1: Subscription Setup ---${NC}"
    gather_subscription_info "" "" ""
    source "$SUBSCRIPTION_CONFIG_FILE" # Load the BASE_URL we just created
    touch "$USERS_FILE_PATH"

    echo -e "\n${BOLD}--- Step 2: Add First User (Optional) ---${NC}"
    echo -e "To start the script correctly, at least one user must be defined."
    echo -e "\n${YELLOW}Note:${NC} If you choose No, you must use the ${BOLD}${RED}User Management${NC} menu later."
    read -p "Do you want to add user(s) now? (y/N): " choice
    if [[ "${choice,,}" == "y" ]]; then
        echo -e "\n${YELLOW}You can add multiple users at once by separating names with a comma (,).${NC}"
        read -p "Enter username(s): " user_input
        if [ -n "$user_input" ]; then
            local user_list_string=${user_input//,/ }
            for username in $user_list_string; do
                if [ -z "$username" ]; then continue; fi
                local new_link="${BASE_URL}${username}"
                if ! grep -qF -- "$new_link" "$USERS_FILE_PATH"; then
                    echo "$new_link" >> "$USERS_FILE_PATH"
                    echo -e "${GREEN}  -> User '$username' added successfully.${NC}"
                else
                    echo -e "${YELLOW}  -> Skipping '$username': User already exists.${NC}"
                fi
            done
        fi
    fi

    echo -e "\n${BOLD}--- Step 3: FTP Credential Setup ---${NC}"
    if ! setup_credentials; then
        echo -e "${RED}Credential setup failed. Aborting installation.${NC}"
        return
    fi

    echo -e "\nInstalling python3-pip..."
    sudo apt-get install -y python3-pip
    if [ -f "$REQUIREMENTS_FILE" ]; then
        echo "Installing Python packages from requirements.txt..."
        pip3 install -r "$REQUIREMENTS_FILE"
    else
        echo -e "${YELLOW}Warning: requirements.txt not found. Installing dependencies manually.${NC}"
        pip3 install requests paramiko python-dotenv cryptography
    fi

    if ! crontab -l 2>/dev/null | grep -Fq "$PYTHON_SCRIPT_PATH"; then
        echo "Adding cron job..."
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    else
        echo "Cron job already exists. Updating."
        (crontab -l 2>/dev/null | grep -vF "$PYTHON_SCRIPT_PATH"; echo "$CRON_JOB") | crontab -
    fi
    echo "Running the script for the first time..."
    /usr/bin/python3 "$PYTHON_SCRIPT_PATH" >>"$LOG_FILE_PATH" 2>&1
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}      Installation completed successfully!${NC}"
    echo -e "${GREEN}  The script will now run automatically every 4 hours.${NC}"
    echo -e "${GREEN}======================================================${NC}"
}

uninstall_script() {
    echo -e "\n${YELLOW}This will remove the cron job, log file, encrypted credentials, subscription settings, and the disabled users list.${NC}"
    echo -e "${BOLD}The main 'users.txt' file will NOT be deleted.${NC}"
    read -p "Are you sure you want to proceed with uninstallation? (y/n): " choice
    if [[ "${choice,,}" != "y" ]]; then
        echo -e "\n${GREEN}Uninstallation cancelled.${NC}"
        return
    fi
    
    echo -e "\nStarting the uninstallation process..."
    
    if crontab -l 2>/dev/null | grep -Fq "$PYTHON_SCRIPT_PATH"; then
        echo "Removing cron job..."
        (crontab -l 2>/dev/null | grep -vF "$PYTHON_SCRIPT_PATH") | crontab -
        echo -e "${GREEN}Cron job removed successfully.${NC}"
    else
        echo -e "${YELLOW}No relevant cron job found to remove.${NC}"
    fi
    
    if [ -d "$CRED_DIR" ]; then
        rm -rf "$CRED_DIR"
        echo -e "${GREEN}Encrypted credential and subscription files removed successfully.${NC}"
    fi
    
    if [ -f "$LOG_FILE_PATH" ]; then
        rm -f "$LOG_FILE_PATH"
        echo -e "${GREEN}Log file removed successfully.${NC}"
    fi

    if [ -f "$DISABLED_USERS_FILE" ]; then
        rm -f "$DISABLED_USERS_FILE"
        echo -e "${GREEN}Disabled users file removed successfully.${NC}"
    fi

    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}      Uninstallation completed!${NC}"
    echo -e "${YELLOW}Note: Python packages and main script files were not removed.${NC}"
    echo -e "${GREEN}======================================================${NC}"
}

run_manually() {
    echo -e "${YELLOW}Running the process manually...${NC}"
    /usr/bin/python3 "$PYTHON_SCRIPT_PATH" >>"$LOG_FILE_PATH" 2>&1
    echo -e "${GREEN}Manual run completed. Check cron_log.txt for details.${NC}"
}

main_menu() {
    while true; do
        show_banner
        echo -e "Please choose an option:"
        echo -e "  ${CYAN}1)${NC} Install or Update the Script"
        echo -e "  ${CYAN}2)${NC} Uninstall the Script"
        echo -e "  ${CYAN}3)${NC} User Management"
        echo -e "  ${CYAN}4)${NC} Run Process Manually"
        echo -e "  ${CYAN}5)${NC} Change Schedule"
        echo -e "  ${CYAN}6)${NC} Change FTP Credentials"
        echo -e "  ${CYAN}7)${NC} Change Subscription Settings"
        echo -e "  ${CYAN}8)${NC} Check Script Status"
        echo -e "  ${CYAN}9)${NC} Exit"
        echo
        read -p "Enter your choice [1-9]: " choice

        case $choice in
        1)
            install_script
            read -p "Press [Enter] to return to the menu..."
            ;;
        2)
            uninstall_script
            read -p "Press [Enter] to return to the menu..."
            ;;
        3)
            user_management_menu
            ;;
        4)
            run_manually
            read -p "Press [Enter] to return to the menu..."
            ;;
        5)
            change_cron_time
            read -p "Press [Enter] to return to the menu..."
            ;;
        6)
            change_credentials
            read -p "Press [Enter] to return to the menu..."
            ;;
        7)
            change_subscription_settings
            read -p "Press [Enter] to return to the menu..."
            ;;
        8)
            check_status
            read -p "Press [Enter] to return to the menu..."
            ;;
        9)
            echo -e "\n${GREEN}Exiting... Bye Bye :D${NC}\n"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 2
            ;;
        esac
    done
}

main_menu
