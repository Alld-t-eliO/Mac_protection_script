system_updates() {
    subsection "MACOS UPDATES"

    updates=$(
        softwareupdate -l 2>&1
    )

    echo "$updates" | append_output

    if echo "$updates" | grep -qi "No new software available"; then
        log_ok "No macOS updates available."
    else
        log_info "Review available macOS updates above."
    fi
}


check_updates() {
    section "UPDATES"

    system_updates
}
