#!/usr/bin/env bash
# Detect the Tailscale IPv4 address of this machine.
# Usage:
#   ./scripts/detect-tailscale-ip.sh          # print the IP
#   ./scripts/detect-tailscale-ip.sh --update  # also update .env TAILSCALE_IP

set -euo pipefail

detect_ip() {
  if command -v tailscale >/dev/null 2>&1; then
    tailscale ip -4 2>/dev/null && return
  fi
  # Fallback: parse from tailscale status if 'tailscale ip' is unavailable
  if command -v tailscale >/dev/null 2>&1; then
    tailscale status --json 2>/dev/null \
      | grep -oP '"TailscaleIPs":\["\K[0-9.]+' \
      && return
  fi
  return 1
}

IP="$(detect_ip)" || {
  echo "error: could not detect Tailscale IP. Is Tailscale running?" >&2
  exit 1
}

echo "$IP"

if [[ "${1:-}" == "--update" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "error: env file not found: $ENV_FILE" >&2
    exit 1
  fi
  OLD_IP="$(grep -E '^TAILSCALE_IP=' "$ENV_FILE" | head -n1 | cut -d= -f2-)"
  if [[ "$OLD_IP" == "$IP" ]]; then
    echo "TAILSCALE_IP already set to $IP in $ENV_FILE" >&2
  else
    sed -i "s/^TAILSCALE_IP=.*/TAILSCALE_IP=$IP/" "$ENV_FILE"
    echo "Updated TAILSCALE_IP from ${OLD_IP:-<unset>} to $IP in $ENV_FILE" >&2
  fi
fi
