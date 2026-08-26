# Mac Security Center

A modular Bash-based security auditing tool for macOS.

Mac Security Center performs a collection of system, security, network, persistence, and application checks and generates a structured timestamped report.

The project is designed primarily as a learning project for Bash scripting, macOS internals, defensive security, system administration, and local security auditing.

It follows the same general philosophy as the VPS Security Checkup project, but uses macOS-native tools and concepts instead of Linux-specific utilities such as `systemctl`, `ufw`, `apt`, or `journalctl`.

---

## Features

### Users

- Lists local user accounts
- Displays UID information
- Lists members of the macOS `admin` group
- Helps identify unexpected administrator accounts

### macOS Security

Checks several built-in Apple security mechanisms:

- FileVault
- Gatekeeper
- System Integrity Protection (SIP)
- XProtect

Example results:

```text
[OK] FileVault encryption is enabled.
[OK] Gatekeeper is enabled.
[OK] SIP is enabled.
[OK] XProtect bundle detected.