security_filevault() {
    subsection "FILEVAULT"

    status=$(fdesetup status 2>/dev/null)
    log "$status"

    if echo "$status" | grep -q "FileVault is On"; then
        log_ok "FileVault encryption is enabled."
    else
        log_warning "FileVault encryption is disabled." "Enable FileVault in System Settings > Privacy & Security > FileVault."
    fi
}


security_gatekeeper() {
    subsection "GATEKEEPER"

    status=$(spctl --status 2>/dev/null)
    log "$status"

    if echo "$status" | grep -q "assessments enabled"; then
        log_ok "Gatekeeper is enabled."
    else
        log_warning "Gatekeeper appears disabled." "Run sudo spctl --master-enable."
    fi
}


security_sip() {
    subsection "SYSTEM INTEGRITY PROTECTION"

    status=$(csrutil status 2>/dev/null)
    log "$status"

    if echo "$status" | grep -q "enabled"; then
        log_ok "SIP is enabled."
    else
        emit_level "${SIP_DISABLED_SEVERITY:-CRITICAL}" "SIP is disabled." "Boot to recoveryOS and run csrutil enable."
    fi
}


security_profiles() {
    subsection "CONFIGURATION PROFILES"

    if ! command -v profiles >/dev/null 2>&1; then
        log_info "profiles command is unavailable."
        return
    fi

    profiles list 2>/dev/null | append_output || log_info "No configuration profile data available."
}


security_unsigned_apps() {
    subsection "UNSIGNED APPLICATIONS"

    apps=$(find /Applications "$HOME/Applications" -maxdepth 2 -name "*.app" -type d -print 2>/dev/null || true)

    if [ -z "$apps" ]; then
        log_info "No applications found in common application directories."
        return
    fi

    while read -r app; do
        [ -z "$app" ] && continue
        if ! codesign --verify "$app" >/dev/null 2>&1; then
            emit_level "${UNSIGNED_APP_SEVERITY:-WARNING}" "Unsigned or invalidly signed app: $app" "Remove the app if untrusted, or reinstall it from a trusted source."
        fi
    done <<< "$apps"
}


security_quarantine_apps() {
    subsection "QUARANTINED APPLICATIONS"

    apps=$(find /Applications "$HOME/Applications" -maxdepth 2 -name "*.app" -type d -print 2>/dev/null || true)

    while read -r app; do
        [ -z "$app" ] && continue
        if xattr -p com.apple.quarantine "$app" >/dev/null 2>&1; then
            log_info "App still has quarantine attribute: $app"
        fi
    done <<< "$apps"
}


security_xprotect() {
    subsection "XPROTECT"

    if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ]; then
        log_ok "XProtect detected."

        defaults read \
            /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info \
            CFBundleShortVersionString 2>/dev/null \
        | append_output
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
    security_profiles
    [ "${CHECK_UNSIGNED_APPS:-false}" = "true" ] && security_unsigned_apps
    [ "${CHECK_QUARANTINE_APPS:-false}" = "true" ] && security_quarantine_apps
}
