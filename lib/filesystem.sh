filesystem_world_writable() {
    subsection "WORLD-WRITABLE FILES"

    files=$(
        find / -xdev -type f -perm -0002 2>/dev/null
    )

    if [ -z "$files" ]; then
        log_ok "No world-writable files detected."
        return
    fi

    count=$(echo "$files" | wc -l)

    log_warning "$count world-writable file(s) detected."

    echo "$files" \
    | append_output
}


filesystem_suid_sgid() {
    subsection "SUID / SGID FILES"

    files=$(
        find / -xdev -type f \
        \( -perm -4000 -o -perm -2000 \) \
        2>/dev/null
    )

    if [ -z "$files" ]; then
        log_ok "No SUID/SGID files detected."
        return
    fi

    log_info "SUID/SGID files detected for review:"

    echo "$files" \
    | append_output
}


filesystem_sensitive_permissions() {
    subsection "SENSITIVE FILE PERMISSIONS"

    files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/gshadow"
        "/etc/ssh/sshd_config"
    )

    for file in "${files[@]}"; do

        if [ ! -e "$file" ]; then
            log_warning "$file does not exist."
            continue
        fi

        permissions=$(stat -c "%a" "$file")
        owner=$(stat -c "%U:%G" "$file")

        log "$file -> permissions=$permissions owner=$owner"
    done
}


check_filesystem() {
    section "FILESYSTEM / PERMISSIONS"

    filesystem_world_writable
    filesystem_suid_sgid
    filesystem_sensitive_permissions
}
