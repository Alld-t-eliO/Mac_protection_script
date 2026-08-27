ip_active_connections() {
    subsection "CONNECTED PUBLIC IPs"

    connected_ips=$(
        ss -tn state established \
        | awk 'NR > 1 {print $5}' \
        | sed 's/^\[//; s/\]$//' \
        | sed 's/:[0-9]*$//' \
        | sort -u
    )

    if [ -z "$connected_ips" ]; then
        log_info "No active remote TCP connections detected."
        return
    fi

    while read -r remote_ip; do
        log " - $remote_ip"
    done <<< "$connected_ips"
}


network_listening_ports() {
    subsection "LISTENING PORTS"

    if ! command -v ss >/dev/null 2>&1; then
        log_error "ss command is unavailable."
        return
    fi

    ss -tulpn 2>/dev/null | append_output
}


check_network() {
    section "NETWORK"

    network_listening_ports
    ip_active_connections
}
