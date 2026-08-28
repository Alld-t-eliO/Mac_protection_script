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
        log_warning "Remote Login / SSH is enabled." "Disable Remote Login in System Settings > General > Sharing if it is not required."
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

    echo "$ssh_ports" | append_output
    log_warning "SSH is listening on TCP port 22." "Disable Remote Login if SSH access is not required."
}


check_ssh() {
    section "SSH / REMOTE ACCESS"

    ssh_remote_login
    ssh_listening
}
