set -o pipefail

SCAN_ID="${SCAN_ID:-$(date +%Y-%m-%d_%H-%M-%S)}"
SCAN_PREFIX="${SCAN_PREFIX:-mac-security-scan}"
LOG_ROOT="${LOG_ROOT:-${SCRIPT_DIR:-$PWD}/logs_scan}"
SCAN_DIR="${SCAN_DIR:-$LOG_ROOT/$SCAN_PREFIX-$SCAN_ID}"
REPORT="${REPORT:-$SCAN_DIR/report.txt}"
SCAN_LOG="${SCAN_LOG:-$SCAN_DIR/scan.log}"
SUMMARY_FILE="${SUMMARY_FILE:-$SCAN_DIR/summary.txt}"
FINDINGS_TSV="${FINDINGS_TSV:-$SCAN_DIR/findings.tsv}"
FINDINGS_JSON="${FINDINGS_JSON:-$SCAN_DIR/findings.json}"
HTML_REPORT="${HTML_REPORT:-$SCAN_DIR/report.html}"
COMPARE_FILE="${COMPARE_FILE:-$SCAN_DIR/compare-last.txt}"

OK_COUNT=0
INFO_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
CRITICAL_COUNT=0
CURRENT_SECTION="START"
SCAN_INITIALIZED=0
STRICT_MODE=0
COMPARE_LAST=0


configure_output_dir() {
    if [ "$SCAN_INITIALIZED" -eq 1 ]; then
        log_error "--output-dir must be provided before scan execution starts."
        return 1
    fi

    LOG_ROOT="$1"
    SCAN_DIR="$LOG_ROOT/$SCAN_PREFIX-$SCAN_ID"
    REPORT="$SCAN_DIR/report.txt"
    SCAN_LOG="$SCAN_DIR/scan.log"
    SUMMARY_FILE="$SCAN_DIR/summary.txt"
    FINDINGS_TSV="$SCAN_DIR/findings.tsv"
    FINDINGS_JSON="$SCAN_DIR/findings.json"
    HTML_REPORT="$SCAN_DIR/report.html"
    COMPARE_FILE="$SCAN_DIR/compare-last.txt"
}


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

    echo -e "${PURPLE}============================================================${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}============================================================${RESET}"

    {
        echo ""
        echo "============================================================"
        echo " $1"
        echo "============================================================"
    } >> "$REPORT"

    {
        echo ""
        echo "============================================================"
        echo " $1"
        echo "============================================================"
    } >> "$SCAN_LOG"
}


subsection() {
    init_scan
    CURRENT_SECTION="$1"

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

    {
        echo ""
        echo "------------------------------------------------------------"
        echo " $1"
        echo "------------------------------------------------------------"
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
        echo "  \"html_report\": \"$(json_escape "$HTML_REPORT")\","
        echo "  \"compare_last\": \"$(json_escape "$COMPARE_FILE")\","
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


html_escape() {
    printf "%s" "$1" \
    | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}


write_summary() {
    score=$((100 - (CRITICAL_COUNT * 20) - (ERROR_COUNT * 10) - (WARNING_COUNT * 5)))
    if [ "$score" -lt 0 ]; then
        score=0
    fi

    {
        echo "Mac Security Center summary"
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


write_html_report() {
    score=$((100 - (CRITICAL_COUNT * 20) - (ERROR_COUNT * 10) - (WARNING_COUNT * 5)))
    if [ "$score" -lt 0 ]; then
        score=0
    fi

    {
        echo "<!doctype html>"
        echo "<html lang=\"en\">"
        echo "<head>"
        echo "<meta charset=\"utf-8\">"
        echo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        echo "<title>Mac Security Center Report</title>"
        echo "<style>"
        echo "body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;margin:0;background:#f6f7f9;color:#15171a}"
        echo "header{background:#111827;color:#fff;padding:28px 32px}"
        echo "main{max-width:1100px;margin:0 auto;padding:24px}"
        echo ".summary{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-top:-34px}"
        echo ".card{background:#fff;border:1px solid #d9dde3;border-radius:8px;padding:16px}"
        echo ".value{font-size:28px;font-weight:700}"
        echo "table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #d9dde3;border-radius:8px;overflow:hidden}"
        echo "th,td{padding:10px 12px;border-bottom:1px solid #e7eaf0;text-align:left;font-size:14px}"
        echo "th{background:#eef1f5}"
        echo ".OK{color:#166534;font-weight:700}.INFO{color:#0369a1;font-weight:700}.WARNING{color:#a16207;font-weight:700}.ERROR,.CRITICAL{color:#b91c1c;font-weight:700}"
        echo "pre{white-space:pre-wrap;background:#fff;border:1px solid #d9dde3;border-radius:8px;padding:16px;overflow:auto}"
        echo "</style>"
        echo "</head>"
        echo "<body>"
        echo "<header><h1>Mac Security Center</h1><p>Scan ID: $(html_escape "$SCAN_ID")</p></header>"
        echo "<main>"
        echo "<section class=\"summary\">"
        echo "<div class=\"card\"><div>Score</div><div class=\"value\">$score/100</div></div>"
        echo "<div class=\"card\"><div>OK</div><div class=\"value\">$OK_COUNT</div></div>"
        echo "<div class=\"card\"><div>Warnings</div><div class=\"value\">$WARNING_COUNT</div></div>"
        echo "<div class=\"card\"><div>Critical</div><div class=\"value\">$CRITICAL_COUNT</div></div>"
        echo "</section>"
        echo "<h2>Findings</h2>"
        echo "<table><thead><tr><th>Severity</th><th>Check</th><th>Message</th></tr></thead><tbody>"

        while IFS=$'\t' read -r severity check message; do
            [ -z "$severity" ] && continue
            echo "<tr><td class=\"$(html_escape "$severity")\">$(html_escape "$severity")</td><td>$(html_escape "$check")</td><td>$(html_escape "$message")</td></tr>"
        done < "$FINDINGS_TSV"

        echo "</tbody></table>"

        if [ -f "$COMPARE_FILE" ]; then
            echo "<h2>Compare Last</h2>"
            echo "<pre>$(html_escape "$(cat "$COMPARE_FILE")")</pre>"
        fi

        echo "<h2>Raw Report</h2>"
        echo "<pre>$(html_escape "$(cat "$REPORT")")</pre>"
        echo "</main></body></html>"
    } > "$HTML_REPORT"
}


compare_last_scan() {
    previous=$(
        find "$LOG_ROOT" -maxdepth 1 -type d -name "$SCAN_PREFIX-*" ! -path "$SCAN_DIR" 2>/dev/null \
        | sort \
        | tail -n 1
    )

    {
        echo "Compare with previous scan"
        echo "Current: $SCAN_DIR"

        if [ -z "$previous" ] || [ ! -f "$previous/findings.tsv" ]; then
            echo "Previous: none"
            echo "No previous scan available for comparison."
        else
            echo "Previous: $previous"
            echo ""
            echo "New findings:"
            comm -13 \
                <(awk -F '\t' '$1 == "CRITICAL" || $1 == "ERROR" || $1 == "WARNING"' "$previous/findings.tsv" | sort) \
                <(awk -F '\t' '$1 == "CRITICAL" || $1 == "ERROR" || $1 == "WARNING"' "$FINDINGS_TSV" | sort) \
            | awk -F '\t' '{print " - [" $1 "] " $2 ": " $3}'
            echo ""
            echo "Resolved findings:"
            comm -23 \
                <(awk -F '\t' '$1 == "CRITICAL" || $1 == "ERROR" || $1 == "WARNING"' "$previous/findings.tsv" | sort) \
                <(awk -F '\t' '$1 == "CRITICAL" || $1 == "ERROR" || $1 == "WARNING"' "$FINDINGS_TSV" | sort) \
            | awk -F '\t' '{print " - [" $1 "] " $2 ": " $3}'
        fi
    } > "$COMPARE_FILE"

    cat "$COMPARE_FILE" | append_output
}


finalize_scan() {
    section "SCAN SUMMARY"

    if [ "$COMPARE_LAST" -eq 1 ]; then
        compare_last_scan
    fi

    write_summary
    cat "$SUMMARY_FILE" | append_output
    write_findings_json
    write_html_report
    log_ok "Scan artifacts saved in: $SCAN_DIR"

    if [ "$STRICT_MODE" -eq 1 ] && [ $((WARNING_COUNT + ERROR_COUNT + CRITICAL_COUNT)) -gt 0 ]; then
        log_error "Strict mode failed because warnings, errors or critical findings were detected."
        return 1
    fi

    return 0
}
