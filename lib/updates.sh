packages_updates_available() {
    subsection "AVAILABLE PACKAGE UPDATES"

    if ! command -v apt >/dev/null 2>&1; then
        log_info "APT is unavailable on this system."
        return
    fi

    updates=$(
        apt list --upgradable 2>/dev/null \
        | tail -n +2
    )

    if [ -z "$updates" ]; then
        log_ok "No package updates available."
        return
    fi

    count=$(echo "$updates" | wc -l)

    log_warning "$count package update(s) available."

    echo "$updates" \
    | append_output
}


packages_security_updates() {
    subsection "SECURITY UPDATES"

    if ! command -v apt >/dev/null 2>&1; then
        log_info "APT is unavailable on this system."
        return
    fi

    security_updates=$(
        apt list --upgradable 2>/dev/null \
        | grep -i security || true
    )

    if [ -z "$security_updates" ]; then
        log_ok "No security updates detected."
        return
    fi

    count=$(echo "$security_updates" | wc -l)

    log_warning "$count security update(s) available."

    echo "$security_updates" \
    | append_output
}


system_reboot_required() {
    subsection "REBOOT REQUIRED"

    if [ -f /var/run/reboot-required ]; then
        log_warning "System reboot is required."

        if [ -f /var/run/reboot-required.pkgs ]; then
            log "Packages requiring reboot:"

            cat /var/run/reboot-required.pkgs \
            | append_output
        fi
    else
        log_ok "No reboot required."
    fi
}


check_updates() {
    section "UPDATES / PACKAGES"

    packages_updates_available
    packages_security_updates
    system_reboot_required
}
