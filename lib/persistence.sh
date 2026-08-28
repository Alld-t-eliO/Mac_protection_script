login_items() {
    subsection "LOGIN ITEMS"

    items=$(
        osascript -e \
        'tell application "System Events" to get the name of every login item' \
        2>/dev/null || true
    )

    if [ -z "$items" ]; then
        log_info "No login items detected or access unavailable."
        return
    fi

    log "$items"
}


launch_agents_user() {
    subsection "USER LAUNCH AGENTS"

    files=$(
        find "$HOME/Library/LaunchAgents" \
            -maxdepth 1 \
            -type f \
            -name "*.plist" \
            -print 2>/dev/null || true
    )

    if [ -z "$files" ]; then
        log_info "No user LaunchAgents found."
        return
    fi

    echo "$files" | append_output

    while read -r file; do
        [ -z "$file" ] && continue
        permissions=$(stat -f "%Sp %Su:%Sg" "$file" 2>/dev/null || true)
        log_info "$file | $permissions"
    done <<< "$files"
}


launch_agents_system() {
    subsection "SYSTEM LAUNCH AGENTS / DAEMONS"

    files=$(
        find /Library/LaunchAgents \
            /Library/LaunchDaemons \
            -maxdepth 1 \
            -type f \
            -name "*.plist" \
            -print 2>/dev/null || true
    )

    if [ -z "$files" ]; then
        log_info "No third-party system LaunchAgents/Daemons found."
        return
    fi

    echo "$files" | append_output

    while read -r file; do
        [ -z "$file" ] && continue
        permissions=$(stat -f "%Sp %Su:%Sg" "$file" 2>/dev/null || true)
        log_info "$file | $permissions"
    done <<< "$files"
}


browser_extensions() {
    subsection "BROWSER EXTENSIONS"

    paths=(
        "$HOME/Library/Application Support/Google/Chrome/Default/Extensions"
        "$HOME/Library/Application Support/Chromium/Default/Extensions"
        "$HOME/Library/Application Support/Firefox/Profiles"
        "$HOME/Library/Safari/Extensions"
    )

    found=0
    for path in "${paths[@]}"; do
        if [ -d "$path" ]; then
            found=1
            log_info "Extension path exists: $path"
            find "$path" -maxdepth 2 -type d 2>/dev/null | head -n 50 | append_output
        fi
    done

    [ "$found" -eq 0 ] && log_info "No common browser extension directories found."
}


suspicious_plist_commands() {
    subsection "SUSPICIOUS PLIST COMMANDS"

    files=$(
        find "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons \
            -maxdepth 1 \
            -type f \
            -name "*.plist" \
            -print 2>/dev/null || true
    )

    if [ -z "$files" ]; then
        log_info "No plist files available for suspicious command review."
        return
    fi

    while read -r file; do
        [ -z "$file" ] && continue
        if grep -Eqi 'curl|wget|nc |netcat|base64|osascript|python|perl|ruby|chmod \+x|/tmp/|/var/tmp/' "$file" 2>/dev/null; then
            log_warning "Potentially suspicious command in plist: $file" "Inspect ProgramArguments and verify the binary path, owner, and signature."
        fi
    done <<< "$files"
}


shell_startup_files() {
    subsection "SHELL STARTUP FILES"

    found=0
    for file in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$file" ]; then
            found=1
            permissions=$(stat -f "%Sp %Su:%Sg" "$file" 2>/dev/null || true)
            log_info "$file | $permissions"
        fi
    done

    if [ "$found" -eq 0 ]; then
        log_info "No common shell startup files found."
    fi
}


check_persistence() {
    section "PERSISTENCE / LOGIN ITEMS"

    login_items
    launch_agents_user
    launch_agents_system
    shell_startup_files
    browser_extensions
    suspicious_plist_commands
}
