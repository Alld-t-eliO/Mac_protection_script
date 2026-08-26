security_filevault() {
    section "FILEVAULT"

    status=$(fdesetup status 2>/dev/null)
    log "$status"

    if echo "$status" | grep -q "FileVault is On"; then
        log_ok "FileVault encryption is enabled."
    else
        log_warning "FileVault encryption is disabled."
    fi
}


security_gatekeeper() {
    section "GATEKEEPER"

    status=$(spctl --status 2>/dev/null)
    log "$status"

    if echo "$status" | grep -q "assessments enabled"; then
        log_ok "Gatekeeper is enabled."
    else
        log_warning "Gatekeeper appears disabled."
    fi
}


security_sip() {
    section "SYSTEM INTEGRITY PROTECTION"

    status=$(csrutil status 2>/dev/null)
    log "$status"

    if echo "$status" | grep -q "enabled"; then
        log_ok "SIP is enabled."
    else
        log_critical "SIP is disabled."
    fi
}


security_xprotect() {
    section "XPROTECT"

    if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ]; then
        log_ok "XProtect detected."
    else
        log_info "XProtect bundle location not detected."
    fi
}


check_security() {
    section "MACOS SECURITY"

    security_filevault
    security_gatekeeper
    security_sip
    security_xprotect
}