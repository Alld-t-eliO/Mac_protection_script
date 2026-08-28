processes_top_cpu() {
    subsection "TOP CPU PROCESSES"

    ps -axo pid,user,%cpu,%mem,command \
    | awk 'NR == 1 {print; next} {print}' \
    | sort -k3,3nr \
    | head -n 11 \
    | append_output
}


processes_top_memory() {
    subsection "TOP MEMORY PROCESSES"

    ps -axo pid,user,%cpu,%mem,command \
    | awk 'NR == 1 {print; next} {print}' \
    | sort -k4,4nr \
    | head -n 11 \
    | append_output
}


processes_root() {
    subsection "ROOT PROCESSES"

    ps -axo user,pid,%cpu,%mem,command \
    | awk 'NR == 1 || $1 == "root"' \
    | append_output
}


check_processes() {
    section "PROCESSES"

    processes_top_cpu
    processes_top_memory
    processes_root
}
