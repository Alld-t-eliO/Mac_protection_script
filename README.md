# Mac Security Center

Mac Security Center is a modular Bash security and system audit tool for macOS.

It checks local users, Apple security controls, network exposure, SSH/remote access, firewall state, sharing services, persistence locations, Homebrew, filesystem permissions, Docker, and system updates. Every scan creates structured artifacts that can be reviewed by a person or consumed by automation.

## Quick Start

```bash
chmod +x main.sh security-checkup.sh install.sh
./main.sh --all
```

Some checks return more complete data when run with administrator privileges:

```bash
sudo ./main.sh --all
```

`security-checkup.sh` is kept as a compatibility wrapper around `main.sh`.

## Installation

To install a global command:

```bash
sudo ./install.sh
mac-checkup --all
```

You can customize the install target:

```bash
sudo TARGET_DIR=/usr/local/bin COMMAND_NAME=mac-security-checkup ./install.sh
```

## Usage

```bash
./main.sh [scan options] [global options]
```

Examples:

```bash
./main.sh --security --network --firewall
./main.sh --persistence --filesystem
./main.sh --all --compare-last
./main.sh --all --strict
./main.sh --all --output-dir "$HOME/Desktop/mac-security-scans"
./main.sh --all --json-only
```

## Scan Options

| Option | Description |
| --- | --- |
| `--all` | Run the complete macOS security checkup. |
| `--users` | List local users and administrator accounts. |
| `--security` | Check FileVault, Gatekeeper, SIP, XProtect, and configuration profiles. Deep app signature/quarantine checks are opt-in through config or the `paranoid` profile. |
| `--network` | Inspect interfaces, listening ports, established connections, DNS, and proxy settings. |
| `--ssh` | Check Remote Login and SSH listeners. |
| `--firewall` | Check the macOS Application Firewall, stealth mode, and app rules. |
| `--sharing` | Detect selected remote sharing services. |
| `--persistence` | Inspect login items, LaunchAgents, LaunchDaemons, shell startup files, and browser extension paths. |
| `--processes` | Show top CPU, top memory, and root-owned processes. |
| `--services` | Check Homebrew services and outdated packages. |
| `--updates` | Check macOS software updates. |
| `--filesystem` | Check SSH key permissions, authorized keys, and selected writable paths. |
| `--docker` | Check Docker daemon state, containers, exposed ports, privileged containers, and container users. |

## Global Options

| Option | Description |
| --- | --- |
| `--strict` | Exit with status code `1` when warnings, errors, or critical findings are detected. Useful for CI and scheduled audits. |
| `--output-dir <path>` | Store scan directories under a custom output directory. |
| `--compare-last` | Compare current warning/error/critical findings with the previous scan in the same output directory. |
| `--quiet` | Suppress terminal output while still writing artifacts. |
| `--json-only` | Suppress normal terminal output and print `findings.json` at the end. |
| `--no-color` | Disable ANSI color output. |
| `--config <path>` | Load a custom Bash config file. |
| `--profile <name>` | Load an audit profile from `profiles/<name>.conf`. Built-ins: `workstation`, `server`, `docker-host`, `paranoid`. |
| `--plugin <name>` | Run one plugin from `plugins/<name>.sh`. |
| `--plugins` | Load and run every plugin in `plugins/`. |
| `--save-baseline` | Save current findings as a signed baseline under `baselines/`. |
| `--compare-baseline` | Compare current findings with the signed baseline and verify the baseline hash. |
| `--format jsonl` | Print JSON Lines findings to stdout and write `findings.jsonl`. |
| `--syslog` | Export findings to local syslog through `logger`. |
| `--webhook-url <url>` | POST `findings.json` to a webhook endpoint. |
| `-h`, `--help` | Show help. |

## Output Files

Each scan creates a timestamped directory:

```text
logs_scan/mac-security-scan-YYYY-MM-DD_HH-MM-SS/
  report.txt
  scan.log
  summary.txt
  findings.tsv
  findings.json
  findings.jsonl
  report.html
  compare-last.txt
  compare-baseline.txt
```

| File | Purpose |
| --- | --- |
| `report.txt` | Human-readable full report. |
| `scan.log` | Raw scan log for archiving or forwarding. |
| `summary.txt` | Score, counts, and top issues. |
| `findings.tsv` | Simple tab-separated finding store used for comparisons. |
| `findings.json` | Structured output for scripts, dashboards, CI, or ingestion. |
| `findings.jsonl` | SIEM-friendly JSON Lines export. |
| `report.html` | Standalone visual report for review in a browser. |
| `compare-last.txt` | Created when `--compare-last` is used. |
| `compare-baseline.txt` | Created when `--compare-baseline` is used. |

## Profiles

Profiles live in `profiles/` and can define default scan sets and severity choices:

```bash
./main.sh --profile workstation
./main.sh --profile server
./main.sh --profile docker-host
./main.sh --profile paranoid
```

When a profile is used without explicit scan options, its `PROFILE_SCANS` list is used.

## Signed Baselines

Create a trusted reference point:

```bash
./main.sh --all --save-baseline
```

Compare future scans with it:

```bash
./main.sh --all --compare-baseline
```

The scanner stores a SHA-256 hash next to the baseline and verifies it before comparison.

## Plugins

Plugins live in `plugins/`. Each plugin exposes a function named after the file:

```bash
plugins/tcc.sh          # exposes check_tcc
plugins/path_integrity.sh # exposes check_path_integrity
```

Run one plugin:

```bash
./main.sh --plugin tcc
```

Run all plugins:

```bash
./main.sh --plugins
```

## Finding Levels

| Level | Meaning |
| --- | --- |
| `OK` | Expected secure or healthy state. |
| `INFO` | Informational data or a non-actionable observation. |
| `WARNING` | Review recommended. May be acceptable depending on your setup. |
| `ERROR` | The scanner could not complete an important check. |
| `CRITICAL` | High-risk condition that should be reviewed quickly. |

Many findings include a `remediation` field in JSON and a `Fix:` hint in terminal output.

## Configuration

Default settings live in:

```text
config/default.conf
```

Use a custom config file:

```bash
./main.sh --all --config ./config/workstation.conf
```

The config is a Bash file, so keep it trusted and local.

## Automation

Run quietly from cron or a scheduled task:

```bash
./main.sh --all --quiet --compare-last --output-dir "$HOME/security-scans"
```

Use strict mode in CI:

```bash
./main.sh --security --firewall --strict
```

Use JSON output for tooling:

```bash
./main.sh --all --json-only > latest-findings.json
./main.sh --all --format jsonl > latest-findings.jsonl
```

Export to syslog or a webhook:

```bash
./main.sh --all --syslog
./main.sh --all --webhook-url https://example.invalid/security-webhook
```

## Repository Validation

The included GitHub Actions workflow validates Bash syntax for:

- `main.sh`
- `security-checkup.sh`
- `install.sh`
- all `lib/*.sh` modules
- all `plugins/*.sh` plugins
- `tests/run.sh`

## Privacy And Safety

The scanner runs locally and writes local artifacts. It does not upload data by itself.

Reports may contain usernames, process names, local paths, network connections, app names, and Docker metadata. Review reports before sharing them publicly.

## Limitations

This tool is an audit helper, not an antivirus, EDR, or full compliance scanner. Some macOS security data is protected by privacy controls and may require Full Disk Access, administrator privileges, or manual verification.
