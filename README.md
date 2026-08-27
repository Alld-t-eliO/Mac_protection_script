# VPS Security Checkup

A modular Bash-based security auditing tool for Linux VPS hosts.

`main.sh` is the main entry point. It orchestrates category modules from `lib/`, runs selected checks, and writes scan artifacts into `logs_scan/`.

## Usage

```bash
sudo ./main.sh --all
./main.sh --ssh --network --users
./main.sh --docker --firewall
./security-checkup.sh --all
```

`security-checkup.sh` is kept as a compatibility wrapper around `main.sh`.

## Scan Artifacts

Each run creates a dedicated directory:

```text
logs_scan/vps-security-scan-YYYY-MM-DD_HH-MM-SS/
  report.txt
  scan.log
  summary.txt
  findings.tsv
  findings.json
```

`summary.txt` contains the global score and top issues. `findings.json` is intended for automation, comparisons, dashboards, or export.

## Modules

- `lib/users.sh`: valid-shell users and UID 0 accounts
- `lib/network.sh`: listening ports and connected remote IPs
- `lib/ssh.sh`: effective SSH config, Fail2Ban, SSH activity
- `lib/firewall.sh`: UFW status and rules
- `lib/docker.sh`: Docker daemon, containers, ports, privileged mode, container users
- `lib/services.sh`: running/enabled/failed services and process views
- `lib/updates.sh`: package updates, security updates, reboot requirement
- `lib/filesystem.sh`: world-writable files, SUID/SGID files, sensitive file permissions

## Notes

Run with `sudo` for complete access to firewall, journal, process, Docker, and filesystem data.
