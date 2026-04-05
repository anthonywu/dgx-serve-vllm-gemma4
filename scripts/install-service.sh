#!/usr/bin/env bash
# Generate gemma4-tailnet.service from the template using the current working
# directory, then install it into systemd.
#
# Usage:
#   sudo ./scripts/install-service.sh            # install & enable
#   sudo ./scripts/install-service.sh --no-enable # install only

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/systemd/gemma4-tailnet.service.template"
UNIT_NAME="gemma4-tailnet.service"
DEST="/etc/systemd/system/$UNIT_NAME"

if [[ $EUID -ne 0 ]]; then
  echo "error: must run as root (use sudo)" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "error: template not found: $TEMPLATE" >&2
  exit 1
fi

sed "s|__WORKING_DIR__|$ROOT_DIR|g" "$TEMPLATE" > "$DEST"
echo "Installed $DEST (WorkingDirectory=$ROOT_DIR)"

systemctl daemon-reload
echo "Reloaded systemd daemon"

if [[ "${1:-}" != "--no-enable" ]]; then
  systemctl enable "$UNIT_NAME"
  echo "Enabled $UNIT_NAME (will start on boot)"
  echo "Start now with: sudo systemctl start $UNIT_NAME"
fi
