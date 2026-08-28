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


homebrew_taps() {
    subsection "HOMEBREW TAPS"

    if ! command -v brew >/dev/null 2>&1; then
        log_info "Homebrew is not installed."
        return
    fi

    taps=$(brew tap 2>/dev/null || true)

    if [ -z "$taps" ]; then
        log_info "No Homebrew taps detected."
        return
    fi

    echo "$taps" | append_output
    echo "$taps" | grep -Ev '^(homebrew/core|homebrew/cask|homebrew/services)$' >/dev/null 2>&1 \
        && log_warning "Non-standard Homebrew taps detected." "Review custom taps and remove those you do not trust." \
        || log_ok "Only standard Homebrew taps detected."
}


check_services() {
    section "SERVICES"

    homebrew_services
    [ "${CHECK_HOMEBREW_OUTDATED:-false}" = "true" ] && homebrew_outdated
    homebrew_taps
}
