firewall_status() {
    section "FIREWALL STATUS"

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
    section "FIREWALL STEALTH MODE"

    firewall="/usr/libexec/ApplicationFirewall/socketfilterfw"

    status=$("$firewall" --getstealthmode 2>/dev/null)

    log "$status"

    if echo "$status" | grep -qi "enabled"; then
        log_ok "Stealth mode is enabled."
    else
        log_info "Stealth mode is disabled."
    fi
}


firewall_rules() {
    section "FIREWALL APPLICATION RULES"

    /usr/libexec/ApplicationFirewall/socketfilterfw \
        --listapps 2>/dev/null \
    | tee -a "$REPORT"
}


check_firewall() {
    section "FIREWALL"

    firewall_status
    firewall_stealth_mode
    firewall_rules
}