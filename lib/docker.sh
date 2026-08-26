docker_available() {
    command -v docker >/dev/null 2>&1 \
    && docker info >/dev/null 2>&1
}


docker_status() {
    section "DOCKER STATUS"

    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker is not installed."
        return
    fi

    if docker info >/dev/null 2>&1; then
        log_ok "Docker daemon is running."
    else
        log_warning "Docker is installed but not running."
    fi
}


docker_containers() {
    section "DOCKER CONTAINERS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    docker ps -a \
        --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" \
    | tee -a "$REPORT"
}


docker_exposed_ports() {
    section "DOCKER EXPOSED PORTS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    docker ps \
        --format "table {{.Names}}\t{{.Ports}}" \
    | tee -a "$REPORT"
}


docker_privileged_containers() {
    section "DOCKER PRIVILEGED CONTAINERS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    containers=$(docker ps -a --format '{{.Names}}')

    if [ -z "$containers" ]; then
        log_info "No Docker containers found."
        return
    fi

    while read -r container; do

        privileged=$(
            docker inspect \
                --format '{{.HostConfig.Privileged}}' \
                "$container"
        )

        if [ "$privileged" = "true" ]; then
            log_warning "$container is privileged."
        else
            log_ok "$container is not privileged."
        fi

    done <<< "$containers"
}


check_docker() {
    section "DOCKER"

    docker_status
    docker_containers
    docker_exposed_ports
    docker_privileged_containers
}