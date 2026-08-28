homebrew_services() {
    subsection "HOMEBREW SERVICES"

    if ! command -v brew >/dev/null 2>&1; then
        log_info "Homebrew is not installed."
        return
    fi

    brew services list 2>/dev/null | append_output
}


homebrew_outdated() {
    subsection "HOMEBREW OUTDATED PACKAGES"

    if ! command -v brew >/dev/null 2>&1; then
        log_info "Homebrew is not installed."
        return
    fi

    outdated=$(brew outdated 2>/dev/null || true)

    if [ -z "$outdated" ]; then
        log_ok "No outdated Homebrew packages detected."
        return
    fi

    echo "$outdated" | append_output
    log_warning "Outdated Homebrew packages detected." "Run brew update && brew upgrade after reviewing changes."
}


check_services() {
    section "SERVICES"

    homebrew_services
    homebrew_outdated
}
