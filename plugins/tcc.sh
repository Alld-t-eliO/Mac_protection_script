check_tcc() {
    section "PLUGIN: TCC PERMISSIONS"

    tcc_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"

    if [ ! -r "$tcc_db" ]; then
        log_info "User TCC database is not readable." "Grant Full Disk Access or run the check manually if TCC review is required."
        return
    fi

    if ! command -v sqlite3 >/dev/null 2>&1; then
        log_info "sqlite3 is unavailable."
        return
    fi

    sqlite3 "$tcc_db" \
        "select service, client, auth_value from access order by service, client limit 200;" 2>/dev/null \
    | append_output
}
