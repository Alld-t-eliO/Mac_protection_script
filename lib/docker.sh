docker_available() {
    command -v docker >/dev/null 2>&1 \
    && docker info >/dev/null 2>&1
}


docker_status() {
    subsection "DOCKER STATUS"

    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker is not installed."
        return
    fi

    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet docker; then
        log_ok "Docker service is active."
    elif docker info >/dev/null 2>&1; then
        log_ok "Docker daemon is reachable."
    else
        log_warning "Docker is installed but not running."
    fi
}


docker_containers() {
    subsection "DOCKER CONTAINERS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    docker ps -a \
        --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" \
    | append_output
}


docker_exposed_ports() {
    subsection "DOCKER EXPOSED PORTS"

    if ! docker_available; then
        log_info "Docker unavailable."
        return
    fi

    docker ps \
        --format "table {{.Names}}\t{{.Ports}}" \
    | append_output
}


docker_privileged_containers() {
    subsection "DOCKER PRIVILEGED CONTAINERS"

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
            log_warning "$container is running in privileged mode."
        else
            log_ok "$container is not privileged."
        fi
    done <<< "$containers"
}


docker_users() {
    subsection "DOCKER CONTAINER USERS"

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
        user=$(
            docker inspect \
                --format '{{.Config.User}}' \
                "$container"
        )

        if [ -z "$user" ]; then
            log_warning "$container uses the image default user, possibly root."
        elif [ "$user" = "root" ] || [ "$user" = "0" ]; then
            log_warning "$container is configured to run as root."
        else
            log_ok "$container runs as user: $user"
        fi
    done <<< "$containers"
}


check_docker() {
    section "DOCKER"

    docker_status
    docker_containers
    docker_exposed_ports
    docker_privileged_containers
    docker_users
}
