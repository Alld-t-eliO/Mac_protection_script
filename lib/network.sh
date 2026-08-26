network_interfaces() {
    section "NETWORK INTERFACES"

    ifconfig \
    | tee -a "$REPORT"
}


network_listening_ports() {
    section "LISTENING PORTS"

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
    section "ACTIVE TCP CONNECTIONS"

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
    section "REMOTE CONNECTED IPs"

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