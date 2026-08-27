firewall_status() {
    subsection "FIREWALL STATUS"

    if ! command -v ufw >/dev/null 2>&1; then
        log_critical "UFW is not installed."
        return
    fi 

    if ! ufw status | grep -q "Status: active"; then
        log_critical "UFW is not active."
        return
    fi

    log_ok "UFW firewall is active."

    ufw status verbose \
    | append_output
}


firewall_rules() {
    subsection "FIREWALL RULES"

    if ! command -v ufw >/dev/null 2>&1; then
        log_info "UFW unavailable."
        return
    fi

    ufw status numbered | append_output
}


check_firewall() {
    section "FIREWALL ACTIVITY / STATE"

    firewall_status
    firewall_rules
    network_listening_ports
}
