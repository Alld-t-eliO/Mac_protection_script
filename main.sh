#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/users.sh"
source "$SCRIPT_DIR/lib/security.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/ssh.sh"
source "$SCRIPT_DIR/lib/firewall.sh"
source "$SCRIPT_DIR/lib/sharing.sh"
source "$SCRIPT_DIR/lib/persistence.sh"
source "$SCRIPT_DIR/lib/processes.sh"
source "$SCRIPT_DIR/lib/services.sh"
source "$SCRIPT_DIR/lib/updates.sh"
source "$SCRIPT_DIR/lib/filesystem.sh"
source "$SCRIPT_DIR/lib/docker.sh"

TOOL_NAME="Mac Security Center"
VERSION="1.1.0"
GITHUB_NAME="Aegon"


banner() {
    echo -e "${PURPLE}"

    cat << 'EOF'

 ____   ____    .__    _________
 \   \ /   /_ __|  |  /   _____/ ____ _____    ____
  \   Y   /  |  \  |  \_____  \_/ ___\\__  \  /    \
   \     /|  |  /  |__/        \  \___ / __ \|   |  \
    \___/ |____/|____/_______  /\___  >____  /___|  /
                             \/     \/     \/     \/

       SECURITY CHECKUP - MAC VERSION

EOF

    echo -e "${CYAN}${TOOL_NAME}${RESET}"
    echo -e "${CYAN}Version : ${VERSION}${RESET}"
    echo -e "${CYAN}GitHub  : ${GITHUB_NAME}${RESET}"
    echo -e "${CYAN}Scan dir: ${SCAN_DIR}${RESET}"
    echo ""
}


header() {
    section "MAC SECURITY CHECKUP"

    log "Date: $(date)"
    log "Hostname: $(hostname)"
    log "User: $(whoami)"
    log "macOS: $(sw_vers -productVersion 2>/dev/null || echo unknown)"
    log "Build: $(sw_vers -buildVersion 2>/dev/null || echo unknown)"
    log "Kernel: $(uname -r)"
    log "Architecture: $(uname -m)"
    log "Uptime: $(uptime)"
}


usage() {
    echo ""
    echo -e "${PURPLE}Usage:${RESET}"
    echo ""
    echo "  $0 [OPTIONS]"
    echo ""
    echo -e "${PURPLE}Available scans:${RESET}"
    echo ""
    echo "  --all          Run complete Mac security checkup"
    echo "  --users        Scan local users and administrators"
    echo "  --security     Scan FileVault, Gatekeeper, SIP and XProtect"
    echo "  --network      Scan interfaces, ports and connections"
    echo "  --ssh          Scan Remote Login and SSH listeners"
    echo "  --firewall     Scan macOS Application Firewall"
    echo "  --sharing      Scan remote/sharing services"
    echo "  --persistence  Scan login items, LaunchAgents and shell startup files"
    echo "  --processes    Scan running processes"
    echo "  --services     Scan Homebrew services"
    echo "  --updates      Check macOS updates"
    echo "  --filesystem   Scan SSH key permissions and writable sensitive paths"
    echo "  --docker       Scan Docker configuration"
    echo ""
    echo "  --strict       Exit with code 1 if warning, error or critical findings exist"
    echo "  --output-dir   Write scan artifacts under a custom directory"
    echo "  --compare-last Compare findings with the previous scan in the output directory"
    echo "  --quiet        Suppress terminal output while keeping scan artifacts"
    echo "  --json-only    Print only findings.json to stdout after the scan"
    echo "  --no-color     Disable ANSI colors"
    echo "  --config       Load a custom config file"
    echo ""
    echo "  -h, --help     Show this help"
    echo ""
    echo -e "${PURPLE}Examples:${RESET}"
    echo ""
    echo "  sudo $0 --all"
    echo "  $0 --security --network --firewall"
    echo "  $0 --persistence --filesystem"
    echo "  $0 --processes --docker"
    echo "  $0 --all --strict --compare-last"
    echo "  $0 --all --output-dir /tmp/mac-scans"
    echo ""
}


scan_all() {
    check_users
    check_security
    check_network
    check_ssh
    check_firewall
    check_sharing
    check_persistence
    check_processes
    check_services
    check_updates
    check_filesystem
    check_docker
}


run_option() {
    option="$1"

    case "$option" in
        --all)
            scan_all
            ;;
        --users)
            check_users
            ;;
        --security)
            check_security
            ;;
        --network)
            check_network
            ;;
        --ssh)
            check_ssh
            ;;
        --firewall)
            check_firewall
            ;;
        --sharing)
            check_sharing
            ;;
        --persistence)
            check_persistence
            ;;
        --processes)
            check_processes
            ;;
        --services)
            check_services
            ;;
        --updates)
            check_updates
            ;;
        --filesystem)
            check_filesystem
            ;;
        --docker)
            check_docker
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $option"
            usage
            ;;
    esac
}


main() {
    if [ "$#" -eq 0 ]; then
        banner
        usage
        exit 0
    fi

    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        banner
        usage
        exit 0
    fi

    SCAN_OPTIONS=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --strict)
                STRICT_MODE=1
                ;;
            --compare-last)
                COMPARE_LAST=1
                ;;
            --quiet)
                QUIET_MODE=1
                ;;
            --json-only)
                JSON_ONLY=1
                QUIET_MODE=1
                ;;
            --no-color)
                RED=""
                CYAN=""
                PURPLE=""
                GREEN=""
                YELLOW=""
                RESET=""
                ;;
            --config)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --config" >&2
                    exit 2
                fi
                CONFIG_FILE="$1"
                # shellcheck source=/dev/null
                source "$CONFIG_FILE"
                ;;
            --config=*)
                CONFIG_FILE="${1#--config=}"
                # shellcheck source=/dev/null
                source "$CONFIG_FILE"
                ;;
            --output-dir)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --output-dir" >&2
                    exit 2
                fi
                configure_output_dir "$1"
                ;;
            --output-dir=*)
                configure_output_dir "${1#--output-dir=}"
                ;;
            *)
                SCAN_OPTIONS+=("$1")
                ;;
        esac

        shift
    done

    if [ "${#SCAN_OPTIONS[@]}" -eq 0 ]; then
        banner
        usage
        exit 0
    fi

    if [ "$QUIET_MODE" -eq 0 ]; then
        banner
    fi
    header

    for option in "${SCAN_OPTIONS[@]}"; do
        run_option "$option"
    done

    finalize_scan
}


main "$@"
