#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${TARGET_DIR:-/usr/local/bin}"
COMMAND_NAME="${COMMAND_NAME:-mac-checkup}"

mkdir -p "$TARGET_DIR"
ln -sf "$SCRIPT_DIR/main.sh" "$TARGET_DIR/$COMMAND_NAME"

echo "Installed $COMMAND_NAME -> $SCRIPT_DIR/main.sh"
