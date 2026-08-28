homebrew_services() {
    subsection "HOMEBREW SERVICES"

    if ! command -v brew >/dev/null 2>&1; then
        log_info "Homebrew is not installed."
        return
    fi

    brew services list 2>/dev/null | append_output
}


check_services() {
    section "SERVICES"

    homebrew_services
}
