#!/usr/bin/env bash

set -u

REPORT="$HOME/security-logs/mac-security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

mkdir -p "$HOME/security-logs"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    CYAN=$'\033[36m'
    VIOLET=$'\033[35m'
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    CYAN=""
    VIOLET=""
    GREEN=""
    RED=""
    BOLD=""
    RESET=""
fi


log() {
    local message="${1-}"

    while IFS= read -r line || [ -n "$line" ]; do
        printf '%s\n' "$line" >> "$REPORT"
        print_color_line "$line"
    done <<< "$message"
}


print_color_line() {
    local line="${1-}"
    local color=""

    case "$line" in
        *"[OK]"*)
            color="$GREEN"
            ;;
        *"[ERROR]"*|*"[CRITICAL]"*)
            color="$RED"
            ;;
        *"[WARNING]"*)
            color="$VIOLET"
            ;;
        *"[INFO]"*)
            color="$CYAN"
            ;;
        "============================================================"|\
        "------------------------------------------------------------")
            color="$CYAN"
            ;;
    esac

    if [ -z "$color" ] && [[ "$line" =~ ^\ [A-Z0-9/\ -]+$ ]]; then
        color="$BOLD$VIOLET"
    fi

    printf '%b%s%b\n' "$color" "$line" "$RESET"
}


section() {
    log ""
    log "============================================================"
    log " $1"
    log "============================================================"
}


subsection() {
    log ""
    log "------------------------------------------------------------"
    log " $1"
    log "------------------------------------------------------------"
}


status_ok() {
    log "[OK] $1"
}


status_info() {
    log "[INFO] $1"
}


status_warning() {
    log "[WARNING] $1"
}


status_error() {
    log "[ERROR] $1"
}


status_critical() {
    log "[CRITICAL] $1"
}


header() {
    section "MAC SECURITY CHECKUP"

    log "Date: $(date)"
    log "Hostname: $(hostname)"
    log "User: $(whoami)"
    log "macOS: $(sw_vers -productVersion)"
    log "Build: $(sw_vers -buildVersion)"
    log "Kernel: $(uname -r)"
    log "Architecture: $(uname -m)"
    log "Uptime: $(uptime)"
}


users_list() {
    subsection "LOCAL USERS"

    dscl . list /Users UniqueID \
    | awk '$2 >= 500 {print " - " $1 " | UID=" $2}' \
    | tee -a "$REPORT"
}


users_admins() {
    subsection "ADMIN USERS"

    admins=$(
        dscl . -read /Groups/admin GroupMembership 2>/dev/null \
        | cut -d ':' -f2-
    )

    if [ -z "$admins" ]; then
        status_warning "Unable to determine admin users."
        return
    fi

    log "Admin accounts:"
    log "$admins"
}


check_users() {
    section "USERS"

    users_list
    users_admins
}


security_filevault() {
    subsection "FILEVAULT"

    status=$(fdesetup status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "FileVault is On"; then
        status_ok "FileVault encryption is enabled."
    else
        status_warning "FileVault encryption is not enabled."
    fi
}


security_gatekeeper() {
    subsection "GATEKEEPER"

    status=$(spctl --status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "assessments enabled"; then
        status_ok "Gatekeeper is enabled."
    else
        status_warning "Gatekeeper appears to be disabled."
    fi
}


security_sip() {
    subsection "SYSTEM INTEGRITY PROTECTION"

    status=$(csrutil status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "enabled"; then
        status_ok "SIP is enabled."
    else
        status_critical "SIP is not enabled."
    fi
}


firewall_status() {
    subsection "FIREWALL STATUS"

    firewall="/usr/libexec/ApplicationFirewall/socketfilterfw"

    if [ ! -x "$firewall" ]; then
        status_error "macOS firewall utility not found."
        return
    fi

    status=$("$firewall" --getglobalstate 2>/dev/null)

    log "$status"

    if echo "$status" | grep -qi "enabled"; then
        status_ok "macOS Application Firewall is enabled."
    else
        status_warning "macOS Application Firewall is disabled."
    fi
}


firewall_stealth_mode() {
    subsection "FIREWALL STEALTH MODE"

    firewall="/usr/libexec/ApplicationFirewall/socketfilterfw"

    status=$("$firewall" --getstealthmode 2>/dev/null)

    log "$status"

    if echo "$status" | grep -qi "enabled"; then
        status_ok "Firewall stealth mode is enabled."
    else
        status_info "Firewall stealth mode is disabled."
    fi
}


firewall_apps() {
    subsection "FIREWALL APPLICATION RULES"

    /usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null \
    | tee -a "$REPORT"
}


check_firewall() {
    section "FIREWALL"

    firewall_status
    firewall_stealth_mode
    firewall_apps
}


network_interfaces() {
    subsection "NETWORK INTERFACES"

    ifconfig \
    | tee -a "$REPORT"
}


network_listening_ports() {
    subsection "LISTENING PORTS"

    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
    | tee -a "$REPORT"
}


network_active_connections() {
    subsection "ACTIVE TCP CONNECTIONS"

    lsof -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null \
    | tee -a "$REPORT"
}


network_public_ips() {
    subsection "REMOTE CONNECTED IPs"

    ips=$(
        lsof -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null \
        | awk 'NR > 1 {print $9}' \
        | awk -F'->' '{print $2}' \
        | sed 's/:[0-9]*$//' \
        | sort -u
    )

    if [ -z "$ips" ]; then
        log "No active remote TCP IPs detected."
        return
    fi

    while read -r remote_ip; do
        [ -n "$remote_ip" ] && log " - $remote_ip"
    done <<< "$ips"
}


check_network() {
    section "NETWORK"

    network_listening_ports
    network_active_connections
    network_public_ips
}


ssh_remote_login() {
    subsection "REMOTE LOGIN / SSH"

    status=$(systemsetup -getremotelogin 2>/dev/null)

    if [ -z "$status" ]; then
        status_info "Run the script with sudo to inspect Remote Login."
        return
    fi

    log "$status"

    if echo "$status" | grep -qi "Off"; then
        status_ok "Remote Login / SSH is disabled."
    else
        status_info "Remote Login / SSH is enabled."
    fi
}


ssh_listening() {
    subsection "SSH LISTENING"

    ssh_ports=$(
        lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
        | grep sshd || true
    )

    if [ -z "$ssh_ports" ]; then
        status_ok "No SSH listener detected."
    else
        log "$ssh_ports"
        status_info "SSH server is currently listening."
    fi
}


check_ssh() {
    section "SSH / REMOTE ACCESS"

    ssh_remote_login
    ssh_listening
}


sharing_services() {
    section "SHARING / REMOTE SERVICES"

    log "Potential Apple sharing services currently listening:"

    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
    | grep -Ei 'screensharing|sshd|smbd|sharingd|rapportd|remoted' \
    | tee -a "$REPORT" || true
}


login_items() {
    subsection "LOGIN ITEMS"

    osascript -e \
        'tell application "System Events" to get the name of every login item' \
        2>/dev/null \
    | tee -a "$REPORT"
}

launch_agents_user() {
    subsection "USER LAUNCH AGENTS"

    find "$HOME/Library/LaunchAgents" \
        -maxdepth 1 \
        -type f \
        -name "*.plist" \
        -print 2>/dev/null \
    | tee -a "$REPORT"
}


launch_agents_system() {
    subsection "SYSTEM LAUNCH AGENTS"

    find /Library/LaunchAgents \
        /Library/LaunchDaemons \
        -maxdepth 1 \
        -type f \
        -name "*.plist" \
        -print 2>/dev/null \
    | tee -a "$REPORT"
}


check_launch_services() {
    section "PERSISTENCE / LAUNCH SERVICES"

    launch_agents_user
    launch_agents_system
}


processes_running() {
    subsection "RUNNING PROCESSES"

    log "Top processes by CPU and memory:"
    ps -axo user,pid,%cpu,%mem,etime,command \
    | awk 'NR > 1' \
    | sort -k3,3nr -k4,4nr \
    | head -n 30 \
    | awk '
        BEGIN {
            printf "%-18s %7s %6s %6s %-12s %s\n", "USER", "PID", "CPU%", "MEM%", "TIME", "COMMAND"
            printf "%-18s %7s %6s %6s %-12s %s\n", "------------------", "-------", "------", "------", "------------", "----------------------------------------"
        }
        {
            user=$1
            pid=$2
            cpu=$3
            mem=$4
            etime=$5
            command=""
            for (i = 6; i <= NF; i++) {
                command = command (i == 6 ? "" : " ") $i
            }
            if (length(command) > 95) {
                command = substr(command, 1, 92) "..."
            }
            printf "%-18s %7s %6s %6s %-12s %s\n", user, pid, cpu, mem, etime, command
        }
    ' \
    | tee -a "$REPORT"

    log ""
    log "Compact full process list:"
    ps -axo user,pid,%cpu,%mem,command \
    | awk '
        NR == 1 {
            printf "%-18s %7s %6s %6s %s\n", "USER", "PID", "CPU%", "MEM%", "COMMAND"
            printf "%-18s %7s %6s %6s %s\n", "------------------", "-------", "------", "------", "----------------------------------------"
            next
        }
        {
            user=$1
            pid=$2
            cpu=$3
            mem=$4
            command=""
            for (i = 5; i <= NF; i++) {
                command = command (i == 5 ? "" : " ") $i
            }
            if (length(command) > 110) {
                command = substr(command, 1, 107) "..."
            }
            printf "%-18s %7s %6s %6s %s\n", user, pid, cpu, mem, command
        }
    ' \
    | tee -a "$REPORT"
}


processes_root() {
    subsection "ROOT PROCESSES"

    ps -axo user,pid,%cpu,%mem,command \
    | awk '$1 == "root"' \
    | tee -a "$REPORT"
}


check_processes() {
    section "PROCESSES"

    processes_running
    processes_root
}


system_updates() {
    section "MACOS UPDATES"

    softwareupdate -l 2>&1 \
    | tee -a "$REPORT"
}


security_xprotect() {
    subsection "XPROTECT"

    if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ]; then
        status_ok "XProtect bundle detected."

        defaults read \
            /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info \
            CFBundleShortVersionString 2>/dev/null \
        | tee -a "$REPORT"
    else
        status_info "XProtect bundle location not detected."
    fi
}

docker_status() {
    subsection "DOCKER STATUS"

    if ! command -v docker >/dev/null 2>&1; then
        status_info "Docker is not installed."
        return
    fi

    if docker info >/dev/null 2>&1; then
        status_ok "Docker daemon is running."
    else
        status_warning "Docker is installed but not running."
    fi
}


docker_containers() {
    subsection "DOCKER CONTAINERS"

    if ! command -v docker >/dev/null 2>&1; then
        return
    fi

    if ! docker info >/dev/null 2>&1; then
        return
    fi

    docker ps -a \
        --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" \
    | tee -a "$REPORT"
}


check_docker() {
    section "DOCKER"

    docker_status
    docker_containers
}


check_security() {
    section "MACOS SECURITY"

    security_filevault
    security_gatekeeper
    security_sip
    security_xprotect
}


main() {
    header
    check_users
    check_security
    check_firewall
    check_network
    check_ssh
    sharing_services
    check_launch_services
    login_items
    check_processes
    system_updates
    check_docker
    section "END OF REPORT"

    log "Security checkup completed."
    log "Report saved to:"
    log "$REPORT"
}

main
