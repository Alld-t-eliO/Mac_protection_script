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
}
