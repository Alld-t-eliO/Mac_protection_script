sharing_services() {
    subsection "SHARING / REMOTE SERVICES"

    services=$(
        lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
        | grep -Ei 'screensharing|sshd|smbd|sharingd|rapportd|remoted' \
        || true
    )

    if [ -z "$services" ]; then
        log_ok "No selected remote sharing services detected."
        return
    fi

    echo "$services" | append_output
    log_warning "Review remote sharing services listed above."
}


check_sharing() {
    section "SHARING SERVICES"

    sharing_services
}
