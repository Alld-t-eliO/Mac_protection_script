ssh_configuration() {
    subsection "SSH CONFIGURATION"

    ssh_config=$(sshd -T 2>/dev/null)

    if [ -z "$ssh_config" ]; then
        log_error "Unable to read effective sshd configuration."
        return
    fi

    root_login=$(
        echo "$ssh_config" \
        | awk '$1 == "permitrootlogin" {print $2}'
    )

    password_auth=$(
        echo "$ssh_config" \
        | awk '$1 == "passwordauthentication" {print $2}'
    )

    log "PermitRootLogin: $root_login"
    log "PasswordAuthentication: $password_auth"

    if [ -z "$root_login" ]; then
        log_error "Unable to determine PermitRootLogin."
    elif [ "$root_login" = "no" ]; then
        log_ok "Root login is disabled."
    else
        log_critical "Root SSH login is not fully disabled: $root_login"
    fi

    if [ -z "$password_auth" ]; then
        log_error "Unable to determine PasswordAuthentication."
    elif [ "$password_auth" = "no" ]; then
        log_ok "Password authentication is disabled."
    else
        log_critical "SSH password authentication is enabled."
    fi
}


ssh_fail2ban() {
    subsection "FAIL2BAN SSH"

    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log_info "Fail2Ban is not installed."
        return
    fi

    if ! systemctl is-active --quiet fail2ban; then
        log_warning "Fail2Ban is not running."
        return
    fi

    fail2ban-client status sshd \
    | append_output
}


ssh_current_connections() {
    subsection "CURRENT SSH CONNECTIONS"

    connections=$(
        ss -tnp 2>/dev/null \
        | grep ssh || true
    )

    if [ -z "$connections" ]; then
        log_info "No current SSH connections detected."
        return
    fi

    echo "$connections" \
    | append_output
}


ssh_successful_connections() {
    subsection "SUCCESSFUL SSH CONNECTIONS"

    journalctl -u ssh --no-pager -q 2>/dev/null \
    | grep "Accepted" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | append_output
}


ssh_failed_attempts() {
    subsection "FAILED SSH ATTEMPTS - LAST 24H"

    journalctl -u ssh --since "24 hours ago" --no-pager -q 2>/dev/null \
    | grep -E "Failed password|Invalid user|authentication failure" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | append_output
}


check_ssh() {
    section "SSH"

    ssh_configuration
    ssh_fail2ban
}


check_ssh_activity() {
    section "SSH ACTIVITY"

    ssh_successful_connections
    ssh_failed_attempts
    ssh_current_connections
}
