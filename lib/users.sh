users_list() {
    section "LOCAL USERS"

    dscl . list /Users UniqueID \
    | awk '$2 >= 500 {
        print " - " $1 " | UID=" $2
    }' \
    | tee -a "$REPORT"
}


users_admins() {
    section "ADMIN USERS"

    admins=$(
        dscl . -read /Groups/admin GroupMembership 2>/dev/null \
        | cut -d ':' -f2-
    )

    if [ -z "$admins" ]; then
        log_warning "Unable to determine admin users."
        return
    fi

    log "Admin accounts:"
    log "$admins"
}


check_users() {
    section "USERS"

    users_list
    users_admins
}