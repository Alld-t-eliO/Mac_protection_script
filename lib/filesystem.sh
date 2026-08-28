ssh_key_permissions() {
    subsection "SSH KEY PERMISSIONS"

    if [ ! -d "$HOME/.ssh" ]; then
        log_info "No ~/.ssh directory found."
        return
    fi

    files=$(find "$HOME/.ssh" -maxdepth 1 -type f -print 2>/dev/null || true)

    while read -r file; do
        [ -z "$file" ] && continue
        permissions=$(stat -f "%Lp %Su:%Sg" "$file" 2>/dev/null || true)

        case "$file" in
            *.pub|known_hosts|config)
                log_info "$file | mode=$permissions"
                ;;
            *)
                mode=$(stat -f "%Lp" "$file" 2>/dev/null || echo 999)
                if [ "$mode" -le 600 ]; then
                    log_ok "$file has restrictive permissions."
                else
                    log_warning "$file may be too permissive: mode=$permissions"
                fi
                ;;
        esac
    done <<< "$files"
}


ssh_authorized_keys() {
    subsection "SSH AUTHORIZED KEYS"

    file="$HOME/.ssh/authorized_keys"

    if [ ! -f "$file" ]; then
        log_info "No authorized_keys file found."
        return
    fi

    permissions=$(stat -f "%Lp %Su:%Sg" "$file" 2>/dev/null || true)
    key_count=$(grep -vc '^[[:space:]]*$' "$file" 2>/dev/null || echo 0)
    log_info "$file | mode=$permissions | keys=$key_count"
}


world_writable_sensitive_paths() {
    subsection "WORLD-WRITABLE SENSITIVE PATHS"

    paths=$(
        find "$HOME" /Library/LaunchAgents /Library/LaunchDaemons \
            -maxdepth 2 \
            -perm -0002 \
            -type d \
            -print 2>/dev/null \
        | head -n 50
    )

    if [ -z "$paths" ]; then
        log_ok "No world-writable sensitive paths found in selected locations."
        return
    fi

    echo "$paths" | append_output
    log_warning "Review world-writable paths listed above."
}


check_filesystem() {
    section "FILESYSTEM"

    ssh_key_permissions
    ssh_authorized_keys
    world_writable_sensitive_paths
}
