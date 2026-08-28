check_path_integrity() {
    section "PLUGIN: PATH INTEGRITY"

    old_ifs="$IFS"
    IFS=":"

    for path_dir in $PATH; do
        [ -z "$path_dir" ] && continue

        if [ ! -d "$path_dir" ]; then
            log_warning "PATH entry does not exist: $path_dir" "Remove stale PATH entries from shell startup files."
            continue
        fi

        permissions=$(stat -f "%Sp %Su:%Sg" "$path_dir" 2>/dev/null || true)
        log_info "$path_dir | $permissions"

        if [ -w "$path_dir" ] && [ ! -O "$path_dir" ]; then
            log_warning "PATH entry is writable by the current user but not owned by it: $path_dir" "Review ownership and permissions for this PATH directory."
        fi
    done

    IFS="$old_ifs"
}
