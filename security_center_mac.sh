#!/usr/bin/env bash

set -u


REPORT="$HOME/security-logs/mac-security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

mkdir -p "$HOME/security-logs"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$'\033[0;31m'
    CYAN=$'\033[0;36m'
    PURPLE=$'\033[0;35m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    RESET=$'\033[0m'
else
    RED=""
    CYAN=""
    PURPLE=""
    GREEN=""
    YELLOW=""
    RESET=""
fi


TOOL_NAME="Mac Security Center"
VERSION="1.0.0"
GITHUB_NAME="Aegon"


log() {
    echo -e "${CYAN}$1${RESET}"
    echo "$1" >> "$REPORT"
}


log_info() {
    echo -e "${CYAN}[INFO] $1${RESET}"
    echo "[INFO] $1" >> "$REPORT"
}


log_ok() {
    echo -e "${GREEN}[OK] $1${RESET}"
    echo "[OK] $1" >> "$REPORT"
}


log_warning() {
    echo -e "${YELLOW}[WARNING] $1${RESET}"
    echo "[WARNING] $1" >> "$REPORT"
}


log_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
    echo "[ERROR] $1" >> "$REPORT"
}


log_critical() {
    echo -e "${RED}[CRITICAL] $1${RESET}"
    echo "[CRITICAL] $1" >> "$REPORT"
}


section() {
    echo ""

    echo -e "${PURPLE}============================================================${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}============================================================${RESET}"

    {
        echo ""
        echo "============================================================"
        echo " $1"
        echo "============================================================"
    } >> "$REPORT"
}


subsection() {
    echo ""

    echo -e "${PURPLE}------------------------------------------------------------${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}------------------------------------------------------------${RESET}"

    {
        echo ""
        echo "------------------------------------------------------------"
        echo " $1"
        echo "------------------------------------------------------------"
    } >> "$REPORT"
}


banner() {

    echo -e "${PURPLE}"

    cat << 'EOF'

____   ____    .__    _________                     
\   \ /   /_ __|  |  /   _____/ ____ _____    ____  
 \   Y   /  |  \  |  \_____  \_/ ___\\__  \  /    \ 
  \     /|  |  /  |__/        \  \___ / __ \|   |  \
   \___/ |____/|____/_______  /\___  >____  /___|  /
                            \/     \/     \/     \/ 

      SECURITY CHECKUP - MAC VERSION

EOF

    echo -e "${CYAN}${TOOL_NAME}${RESET}"
    echo -e "${CYAN}Version : ${VERSION}${RESET}"
    echo -e "${CYAN}GitHub  : ${GITHUB_NAME}${RESET}"
    echo ""
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
        log_warning "Unable to determine admin users."
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
        log_ok "FileVault encryption is enabled."
    else
        log_warning "FileVault encryption is not enabled."
    fi
}


security_gatekeeper() {
    subsection "GATEKEEPER"

    status=$(spctl --status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "assessments enabled"; then
        log_ok "Gatekeeper is enabled."
    else
        log_warning "Gatekeeper appears to be disabled."
    fi
}


security_sip() {
    subsection "SYSTEM INTEGRITY PROTECTION"

    status=$(csrutil status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "enabled"; then
        log_ok "SIP is enabled."
    else
        log_critical "SIP is not enabled."
    fi
}


security_xprotect() {
    subsection "XPROTECT"

    if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ]; then
        log_ok "XProtect bundle detected."

        defaults read \
            /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info \
            CFBundleShortVersionString 2>/dev/null \
        | tee -a "$REPORT"

    else
        log_info "XProtect bundle location not detected."
    fi
}


check_security() {
    section "MACOS SECURITY"

    security_filevault
    security_gatekeeper
    security_sip
    security_xprotect
}


firewall_status() {
    subsection "FIREWALL STATUS"

    firewall="/usr/libexec/ApplicationFirewall/socketfilterfw"

    if [ ! -x "$firewall" ]; then
        log_error "macOS firewall utility not found."
        return
    fi

    status=$("$firewall" --getglobalstate 2>/dev/null)

    log "$status"

    if echo "$status" | grep -qi "enabled"; then
        log_ok "macOS Application Firewall is enabled."
    else
        log_warning "macOS Application Firewall is disabled."
    fi
}


firewall_stealth_mode() {
    subsection "FIREWALL STEALTH MODE"

    firewall="/usr/libexec/ApplicationFirewall/socketfilterfw"

    status=$("$firewall" --getstealthmode 2>/dev/null)

    log "$status"

    if echo "$status" | grep -qiE "enabled|on"; then
        log_ok "Firewall stealth mode is enabled."
    else
        log_info "Firewall stealth mode is disabled."
    fi
}


firewall_apps() {
    subsection "FIREWALL APPLICATION RULES"

    /usr/libexec/ApplicationFirewall/socketfilterfw \
        --listapps 2>/dev/null \
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

    listeners=$(
        lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null || true
    )

    if [ -z "$listeners" ]; then
        log_info "No listening TCP ports detected."
        return
    fi

    echo "$listeners" \
    | tee -a "$REPORT"
}


network_active_connections() {
    subsection "ACTIVE TCP CONNECTIONS"

    connections=$(
        lsof -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null || true
    )

    if [ -z "$connections" ]; then
        log_info "No established TCP connections detected."
        return
    fi

    echo "$connections" \
    | tee -a "$REPORT"
}


network_remote_ips() {
    subsection "REMOTE CONNECTED IPs"

    ips=$(
        lsof -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null \
        | awk 'NR > 1 {print $9}' \
        | awk -F'->' 'NF == 2 {print $2}' \
        | sed 's/:[0-9]*$//' \
        | sort -u
    )

    if [ -z "$ips" ]; then
        log_info "No active remote TCP IPs detected."
        return
    fi

    while read -r remote_ip; do
        [ -n "$remote_ip" ] && log " - $remote_ip"
    done <<< "$ips"
}


check_network() {
    section "NETWORK"

    network_interfaces
    network_listening_ports
    network_active_connections
    network_remote_ips
}


ssh_remote_login() {
    subsection "REMOTE LOGIN / SSH"

    status=$(systemsetup -getremotelogin 2>/dev/null || true)

    if [ -z "$status" ]; then
        log_info "Run with sudo to inspect Remote Login."
        return
    fi

    log "$status"

    if echo "$status" | grep -qi "Off"; then
        log_ok "Remote Login / SSH is disabled."
    else
        log_info "Remote Login / SSH is enabled."
    fi
}


ssh_listening() {
    subsection "SSH LISTENING"

    ssh_ports=$(
        lsof -nP -iTCP:22 -sTCP:LISTEN 2>/dev/null || true
    )

    if [ -z "$ssh_ports" ]; then
        log_ok "No SSH listener detected."
        return
    fi

    echo "$ssh_ports" \
    | tee -a "$REPORT"

    log_info "SSH is listening on TCP port 22."
}


check_ssh() {
    section "SSH / REMOTE ACCESS"

    ssh_remote_login
    ssh_listening
}


sharing_services() {
    subsection "SHARING / REMOTE SERVICES"

    services=$(
        lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
        | grep -Ei \
        'screensharing|sshd|smbd|sharingd|rapportd|remoted' \
        || true
    )

    if [ -z "$services" ]; then
        log_ok "No selected remote sharing services detected."
        return
    fi

    echo "$services" \
    | tee -a "$REPORT"
}


check_sharing() {
    section "SHARING SERVICES"

    sharing_services
}


login_items() {
    subsection "LOGIN ITEMS"

    items=$(
        osascript -e \
        'tell application "System Events" to get the name of every login item' \
        2>/dev/null || true
    )

    if [ -z "$items" ]; then
        log_info "No login items detected or access unavailable."
        return
    fi

    log "$items"
}


launch_agents_user() {
    subsection "USER LAUNCH AGENTS"

    files=$(
        find "$HOME/Library/LaunchAgents" \
            -maxdepth 1 \
            -type f \
            -name "*.plist" \
            -print 2>/dev/null || true
    )

    if [ -z "$files" ]; then
        log_info "No user LaunchAgents found."
        return
    fi

    echo "$files" \
    | tee -a "$REPORT"
}


launch_agents_system() {
    subsection "SYSTEM LAUNCH AGENTS / DAEMONS"

    files=$(
        find /Library/LaunchAgents \
            /Library/LaunchDaemons \
            -maxdepth 1 \
            -type f \
            -name "*.plist" \
            -print 2>/dev/null || true
    )

    if [ -z "$files" ]; then
        log_info "No third-party system LaunchAgents/Daemons found."
        return
    fi

    echo "$files" \
    | tee -a "$REPORT"
}


check_persistence() {
    section "PERSISTENCE / LOGIN ITEMS"

    login_items
    launch_agents_user
    launch_agents_system
}


processes_top_cpu() {
    subsection "TOP CPU PROCESSES"

    ps -axo pid,user,%cpu,%mem,command \
    | awk 'NR == 1 {print; next} {print}' \
    | sort -k3,3nr \
    | head -n 11 \
    | tee -a "$REPORT"
}


processes_top_memory() {
    subsection "TOP MEMORY PROCESSES"

    ps -axo pid,user,%cpu,%mem,command \
    | awk 'NR == 1 {print; next} {print}' \
    | sort -k4,4nr \
    | head -n 11 \
    | tee -a "$REPORT"
}


processes_root() {
    subsection "ROOT PROCESSES"

    ps -axo user,pid,%cpu,%mem,command \
    | awk 'NR == 1 || $1 == "root"' \
    | tee -a "$REPORT"
}


check_processes() {
    section "PROCESSES"

    processes_top_cpu
    processes_top_memory
    processes_root
}


system_updates() {
    subsection "MACOS UPDATES"

    updates=$(
        softwareupdate -l 2>&1
    )

    echo "$updates" \
    | tee -a "$REPORT"

    if echo "$updates" | grep -qi "No new software available"; then
        log_ok "No macOS updates available."
    else
        log_info "Review available macOS updates above."
    fi
}


check_updates() {
    section "UPDATES"

    system_updates
}


docker_available() {
    command -v docker >/dev/null 2>&1 \
    && docker info >/dev/null 2>&1
}


docker_status() {
    subsection "DOCKER STATUS"

    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker is not installed."
        return
    fi

    if docker info >/dev/null 2>&1; then
        log_ok "Docker daemon is running."
    else
        log_warning "Docker is installed but not running."
    fi
}


docker_containers() {
    subsection "DOCKER CONTAINERS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    docker ps -a \
        --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" \
    | tee -a "$REPORT"
}


docker_exposed_ports() {
    subsection "DOCKER EXPOSED PORTS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    docker ps \
        --format "table {{.Names}}\t{{.Ports}}" \
    | tee -a "$REPORT"
}


docker_privileged_containers() {
    subsection "DOCKER PRIVILEGED CONTAINERS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    containers=$(docker ps -a --format '{{.Names}}')

    if [ -z "$containers" ]; then
        log_info "No Docker containers found."
        return
    fi

    while read -r container; do

        privileged=$(
            docker inspect \
                --format '{{.HostConfig.Privileged}}' \
                "$container"
        )

        if [ "$privileged" = "true" ]; then
            log_warning "$container is running in privileged mode."
        else
            log_ok "$container is not privileged."
        fi

    done <<< "$containers"
}


docker_users() {
    subsection "DOCKER CONTAINER USERS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    containers=$(docker ps -a --format '{{.Names}}')

    if [ -z "$containers" ]; then
        log_info "No Docker containers found."
        return
    fi

    while read -r container; do

        user=$(
            docker inspect \
                --format '{{.Config.User}}' \
                "$container"
        )

        if [ -z "$user" ]; then
            log_warning "$container uses the image default user (possibly root)."
        elif [ "$user" = "root" ] || [ "$user" = "0" ]; then
            log_warning "$container is configured to run as root."
        else
            log_ok "$container runs as user: $user"
        fi

    done <<< "$containers"
}


check_docker() {
    section "DOCKER"

    docker_status
    docker_containers
    docker_exposed_ports
    docker_privileged_containers
    docker_users
}


usage() {

    echo ""
    echo -e "${PURPLE}Usage:${RESET}"
    echo ""
    echo "  $0 [OPTIONS]"
    echo ""

    echo -e "${PURPLE}Available scans:${RESET}"
    echo ""

    echo "  --all          Run complete Mac security checkup"
    echo "  --users        Scan local users and administrators"
    echo "  --security     Scan FileVault, Gatekeeper, SIP and XProtect"
    echo "  --network      Scan interfaces, ports and connections"
    echo "  --ssh          Scan Remote Login and SSH listeners"
    echo "  --firewall     Scan macOS Application Firewall"
    echo "  --sharing      Scan remote/sharing services"
    echo "  --persistence  Scan login items and LaunchAgents"
    echo "  --processes    Scan running processes"
    echo "  --updates      Check macOS updates"
    echo "  --docker       Scan Docker configuration"
    echo ""
    echo "  -h, --help     Show this help"
    echo ""

    echo -e "${PURPLE}Examples:${RESET}"
    echo ""
    echo "  sudo $0 --all"
    echo "  sudo $0 --security"
    echo "  sudo $0 --network --firewall"
    echo "  sudo $0 --ssh --sharing"
    echo "  sudo $0 --processes --docker"
    echo ""
}


scan_all() {

    check_users
    check_security
    check_network
    check_ssh
    check_firewall
    check_sharing
    check_persistence
    check_processes
    check_updates
    check_docker
}


main() {

    if [ "$#" -eq 0 ]; then
        banner
        usage
        exit 0
    fi

    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        banner
        usage
        exit 0
    fi

    banner
    header

    for option in "$@"; do

        case "$option" in

            --all)
                scan_all
                ;;

            --users)
                check_users
                ;;

            --security)
                check_security
                ;;

            --network)
                check_network
                ;;

            --ssh)
                check_ssh
                ;;

            --firewall)
                check_firewall
                ;;

            --sharing)
                check_sharing
                ;;

            --persistence)
                check_persistence
                ;;

            --processes)
                check_processes
                ;;

            --updates)
                check_updates
                ;;

            --docker)
                check_docker
                ;;

            -h|--help)
                usage
                ;;

            *)
                log_error "Unknown option: $option"
                echo ""
                usage
                ;;

        esac
    done

    section "END OF CHECKUP"

    log_ok "Mac security checkup completed."
    log "Report saved to: $REPORT"
}


main "$@"