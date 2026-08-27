services_running() {
    subsection "RUNNING SERVICES"

    systemctl \
        --type=service \
        --state=running \
        --no-pager \
    | append_output
}


services_enabled() {
    subsection "ENABLED SERVICES"

    systemctl list-unit-files \
        --type=service \
        --state=enabled \
        --no-pager \
    | append_output
}


services_failed() {
    subsection "FAILED SERVICES"

    failed_services=$(
        systemctl --failed \
            --type=service \
            --no-pager \
            --no-legend
    )

    if [ -z "$failed_services" ]; then
        log_ok "No failed services detected."
        return
    fi

    log_warning "Failed services detected:"

    echo "$failed_services" \
    | append_output
}


processes_root() {
    subsection "ROOT PROCESSES"

    ps -eo user,pid,ppid,%cpu,%mem,comm \
    | awk 'NR == 1 || $1 == "root"' \
    | append_output
}


processes_top_cpu() {
    subsection "TOP CPU PROCESSES"

    ps -eo pid,user,%cpu,%mem,comm \
        --sort=-%cpu \
    | head -n 11 \
    | append_output
}


processes_top_memory() {
    subsection "TOP MEMORY PROCESSES"

    ps -eo pid,user,%cpu,%mem,comm \
        --sort=-%mem \
    | head -n 11 \
    | append_output
}


check_services_processes() {
    section "SERVICES / PROCESSES"

    services_running
    services_enabled
    services_failed
    processes_root
    processes_top_cpu
    processes_top_memory
}
