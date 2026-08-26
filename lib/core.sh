
REPORT="$HOME/security-logs/mac-security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

mkdir -p "$HOME/security-logs"


if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then

    RED=$'\033[0;31m'
    CYAN=$'\033[0;36m'
    PURPLE=$'\033[0;35m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    RESET=$'\033[0m'

else

    RED=""
    CYAN=""
    PURPLE=""
    GREEN=""
    YELLOW=""
    RESET=""

fi


log() {
    echo -e "${CYAN}$1${RESET}"
    echo "$1" >> "$REPORT"
}


log_info() {
    echo -e "${CYAN}[INFO] $1${RESET}"
    echo "[INFO] $1" >> "$REPORT"
}


log_ok() {
    echo -e "${GREEN}[OK] $1${RESET}"
    echo "[OK] $1" >> "$REPORT"
}


log_warning() {
    echo -e "${YELLOW}[WARNING] $1${RESET}"
    echo "[WARNING] $1" >> "$REPORT"
}


log_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
    echo "[ERROR] $1" >> "$REPORT"
}


log_critical() {
    echo -e "${RED}[CRITICAL] $1${RESET}"
    echo "[CRITICAL] $1" >> "$REPORT"
}


section() {

    echo ""

    echo -e "${PURPLE}============================================================${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}============================================================${RESET}"

    {
        echo ""
        echo "============================================================"
        echo " $1"
        echo "============================================================"
    } >> "$REPORT"
}


subsection() {

    echo ""

    echo -e "${PURPLE}------------------------------------------------------------${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}------------------------------------------------------------${RESET}"

    {
        echo ""
        echo "------------------------------------------------------------"
        echo " $1"
        echo "------------------------------------------------------------"
    } >> "$REPORT"
}