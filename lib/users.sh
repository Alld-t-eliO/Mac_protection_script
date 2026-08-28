users_list() {
    subsection "LOCAL USERS"

    users=$(
        dscl . list /Users UniqueID 2>/dev/null \
        | awk '$2 >= 500 {
            print " - " $1 " | UID=" $2
        }'
    )

    if [ -z "$users" ]; then
        log_warning "Unable to list local users."
        return
    fi

    echo "$users" | append_output
}


users_admins() {
    subsection "ADMIN USERS"

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
