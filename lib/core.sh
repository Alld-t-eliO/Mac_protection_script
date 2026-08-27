SCAN_ID="${SCAN_ID:-$(date +%Y-%m-%d_%H-%M-%S)}"
LOG_ROOT="${LOG_ROOT:-${SCRIPT_DIR:-$PWD}/logs_scan}"
SCAN_DIR="${SCAN_DIR:-$LOG_ROOT/vps-security-scan-$SCAN_ID}"
REPORT="${REPORT:-$SCAN_DIR/report.txt}"
SCAN_LOG="${SCAN_LOG:-$SCAN_DIR/scan.log}"
SUMMARY_FILE="${SUMMARY_FILE:-$SCAN_DIR/summary.txt}"
FINDINGS_TSV="${FINDINGS_TSV:-$SCAN_DIR/findings.tsv}"
FINDINGS_JSON="${FINDINGS_JSON:-$SCAN_DIR/findings.json}"

OK_COUNT=0
INFO_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
CRITICAL_COUNT=0
CURRENT_SECTION="START"
SCAN_INITIALIZED=0


init_scan() {
    if [ "$SCAN_INITIALIZED" -eq 1 ]; then
        return
    fi

    mkdir -p "$SCAN_DIR"
    : > "$REPORT"
    : > "$SCAN_LOG"
    : > "$FINDINGS_TSV"

    SCAN_INITIALIZED=1
}


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


append_output() {
    init_scan
    tee -a "$REPORT" "$SCAN_LOG"
}


record_finding() {
    init_scan
    severity="$1"
    message="$2"

    printf "%s\t%s\t%s\n" "$severity" "$CURRENT_SECTION" "$message" >> "$FINDINGS_TSV"
}


log() {
    init_scan
    echo -e "${CYAN}$1${RESET}"
    echo "$1" >> "$REPORT"
    echo "$1" >> "$SCAN_LOG"
}


log_info() {
    INFO_COUNT=$((INFO_COUNT + 1))
    record_finding "INFO" "$1"
    echo -e "${CYAN}[INFO] $1${RESET}"
    echo "[INFO] $1" >> "$REPORT"
    echo "[INFO] $1" >> "$SCAN_LOG"
}


log_ok() {
    OK_COUNT=$((OK_COUNT + 1))
    record_finding "OK" "$1"
    echo -e "${GREEN}[OK] $1${RESET}"
    echo "[OK] $1" >> "$REPORT"
    echo "[OK] $1" >> "$SCAN_LOG"
}


log_warning() {
    WARNING_COUNT=$((WARNING_COUNT + 1))
    record_finding "WARNING" "$1"
    echo -e "${YELLOW}[WARNING] $1${RESET}"
    echo "[WARNING] $1" >> "$REPORT"
    echo "[WARNING] $1" >> "$SCAN_LOG"
}


log_error() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
    record_finding "ERROR" "$1"
    echo -e "${RED}[ERROR] $1${RESET}"
    echo "[ERROR] $1" >> "$REPORT"
    echo "[ERROR] $1" >> "$SCAN_LOG"
}


log_critical() {
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    record_finding "CRITICAL" "$1"
    echo -e "${RED}[CRITICAL] $1${RESET}"
    echo "[CRITICAL] $1" >> "$REPORT"
    echo "[CRITICAL] $1" >> "$SCAN_LOG"
}


section() {
    init_scan
    CURRENT_SECTION="$1"

    echo ""

    echo -e "${PURPLE}==============================${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}==============================${RESET}"

    {
        echo ""
        echo "=============================="
        echo " $1"
        echo "=============================="
    } >> "$REPORT"

    {
        echo ""
        echo "=============================="
        echo " $1"
        echo "=============================="
    } >> "$SCAN_LOG"
}


subsection() {
    init_scan
    CURRENT_SECTION="$1"

    echo ""

    echo -e "${PURPLE}------------------------------${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}------------------------------${RESET}"

    {
        echo ""
        echo "------------------------------"
        echo " $1"
        echo "------------------------------"
    } >> "$REPORT"

    {
        echo ""
        echo "------------------------------"
        echo " $1"
        echo "------------------------------"
    } >> "$SCAN_LOG"
}


json_escape() {
    printf "%s" "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}


write_findings_json() {
    {
        echo "{"
        echo "  \"scan_id\": \"$(json_escape "$SCAN_ID")\","
        echo "  \"report\": \"$(json_escape "$REPORT")\","
        echo "  \"log\": \"$(json_escape "$SCAN_LOG")\","
        echo "  \"summary\": {"
        echo "    \"ok\": $OK_COUNT,"
        echo "    \"info\": $INFO_COUNT,"
        echo "    \"warning\": $WARNING_COUNT,"
        echo "    \"error\": $ERROR_COUNT,"
        echo "    \"critical\": $CRITICAL_COUNT"
        echo "  },"
        echo "  \"findings\": ["

        first=1
        while IFS=$'\t' read -r severity check message; do
            [ -z "$severity" ] && continue

            if [ "$first" -eq 0 ]; then
                echo ","
            fi

            printf "    {\"severity\":\"%s\",\"check\":\"%s\",\"message\":\"%s\"}" \
                "$(json_escape "$severity")" \
                "$(json_escape "$check")" \
                "$(json_escape "$message")"
            first=0
        done < "$FINDINGS_TSV"

        echo ""
        echo "  ]"
        echo "}"
    } > "$FINDINGS_JSON"
}


write_summary() {
    score=$((100 - (CRITICAL_COUNT * 20) - (ERROR_COUNT * 10) - (WARNING_COUNT * 5)))
    if [ "$score" -lt 0 ]; then
        score=0
    fi

    {
        echo "VPS Security Checkup summary"
        echo "Scan ID: $SCAN_ID"
        echo "Score: $score/100"
        echo "OK: $OK_COUNT"
        echo "Info: $INFO_COUNT"
        echo "Warnings: $WARNING_COUNT"
        echo "Errors: $ERROR_COUNT"
        echo "Critical: $CRITICAL_COUNT"
        echo ""
        echo "Top issues:"
        awk -F '\t' '$1 == "CRITICAL" || $1 == "ERROR" || $1 == "WARNING" {print " - [" $1 "] " $2 ": " $3}' "$FINDINGS_TSV"
    } > "$SUMMARY_FILE"
}


finalize_scan() {
    section "SCAN SUMMARY"
    write_summary
    write_findings_json

    cat "$SUMMARY_FILE" | append_output
    log_ok "Scan artifacts saved in: $SCAN_DIR"
}
