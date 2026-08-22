#!/usr/bin/env bash

set -u

REPORT="$HOME/security-logs/mac-security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

mkdir -p "$HOME/security-logs"


log() {
    echo "$1" | tee -a "$REPORT"
}


section() {
    log ""
    log "============================================================"
    log " $1"
    log "============================================================"
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
    section "LOCAL USERS"

    dscl . list /Users UniqueID \
    | awk '$2 >= 500 {print " - " $1 " | UID=" $2}' \
    | tee -a "$REPORT"
}


users_admins() {
    section "ADMIN USERS"

    admins=$(
        dscl . -read /Groups/admin GroupMembership 2>/dev/null \
        | cut -d ':' -f2-
    )

    if [ -z "$admins" ]; then
        log "[WARNING] Unable to determine admin users."
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
    section "FILEVAULT"

    status=$(fdesetup status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "FileVault is On"; then
        log "[OK] FileVault encryption is enabled."
    else
        log "[WARNING] FileVault encryption is not enabled."
    fi
}


security_gatekeeper() {
    section "GATEKEEPER"

    status=$(spctl --status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "assessments enabled"; then
        log "[OK] Gatekeeper is enabled."
    else
        log "[WARNING] Gatekeeper appears to be disabled."
    fi
}


security_sip() {
    section "SYSTEM INTEGRITY PROTECTION"

    status=$(csrutil status 2>/dev/null)

    log "$status"

    if echo "$status" | grep -q "enabled"; then
        log "[OK] SIP is enabled."
    else
        log "[CRITICAL] SIP is not enabled."
    fi
}


firewall_status() {
    section "FIREWALL STATUS"

    firewall="/usr/libexec/ApplicationFirewall/socketfilterfw"

    if [ ! -x "$firewall" ]; then
        log "[ERROR] macOS firewall utility not found."
        return
    fi

    status=$("$firewall" --getglobalstate 2>/dev/null)

    log "$status"

    if echo "$status" | grep -qi "enabled"; then
        log "[OK] macOS Application Firewall is enabled."
    else
        log "[WARNING] macOS Application Firewall is disabled."
    fi
}


firewall_stealth_mode() {
    section "FIREWALL STEALTH MODE"

    firewall="/usr/libexec/ApplicationFirewall/socketfilterfw"

    status=$("$firewall" --getstealthmode 2>/dev/null)

    log "$status"

    if echo "$status" | grep -qi "enabled"; then
        log "[OK] Firewall stealth mode is enabled."
    else
        log "[INFO] Firewall stealth mode is disabled."
    fi
}


firewall_apps() {
    section "FIREWALL APPLICATION RULES"

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
    section "NETWORK INTERFACES"

    ifconfig \
    | tee -a "$REPORT"
}


network_listening_ports() {
    section "LISTENING PORTS"

    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
    | tee -a "$REPORT"
}


network_active_connections() {
    section "ACTIVE TCP CONNECTIONS"

    lsof -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null \
    | tee -a "$REPORT"
}


network_public_ips() {
    section "REMOTE CONNECTED IPs"

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
    section "REMOTE LOGIN / SSH"

    status=$(systemsetup -getremotelogin 2>/dev/null)

    if [ -z "$status" ]; then
        log "[INFO] Run the script with sudo to inspect Remote Login."
        return
    fi

    log "$status"

    if echo "$status" | grep -qi "Off"; then
        log "[OK] Remote Login / SSH is disabled."
    else
        log "[INFO] Remote Login / SSH is enabled."
    fi
}


ssh_listening() {
    section "SSH LISTENING"

    ssh_ports=$(
        lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
        | grep sshd || true
    )

    if [ -z "$ssh_ports" ]; then
        log "[OK] No SSH listener detected."
    else
        log "$ssh_ports"
        log "[INFO] SSH server is currently listening."
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
    section "LOGIN ITEMS"

    osascript -e \
        'tell application "System Events" to get the name of every login item' \
        2>/dev/null \
    | tee -a "$REPORT"
}

launch_agents_user() {
    section "USER LAUNCH AGENTS"

    find "$HOME/Library/LaunchAgents" \
        -maxdepth 1 \
        -type f \
        -name "*.plist" \
        -print 2>/dev/null \
    | tee -a "$REPORT"
}


launch_agents_system() {
    section "SYSTEM LAUNCH AGENTS"

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
    section "RUNNING PROCESSES"

    ps aux \
    | tee -a "$REPORT"
}


processes_root() {
    section "ROOT PROCESSES"

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
    section "XPROTECT"

    if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ]; then
        log "[OK] XProtect bundle detected."

        defaults read \
            /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info \
            CFBundleShortVersionString 2>/dev/null \
        | tee -a "$REPORT"
    else
        log "[INFO] XProtect bundle location not detected."
    fi
}

docker_status() {
    section "DOCKER STATUS"

    if ! command -v docker >/dev/null 2>&1; then
        log "[INFO] Docker is not installed."
        return
    fi

    if docker info >/dev/null 2>&1; then
        log "[OK] Docker daemon is running."
    else
        log "[WARNING] Docker is installed but not running."
    fi
}


docker_containers() {
    section "DOCKER CONTAINERS"

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
    log ""

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