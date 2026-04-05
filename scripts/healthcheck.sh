#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

read_env() {
  local key="$1"
  grep -E "^${key}=" "$ENV_FILE" | head -n1 | cut -d= -f2-
}

TAILSCALE_IP="$(read_env TAILSCALE_IP)"
VLLM_PORT="$(read_env VLLM_PORT)"
VLLM_LOCAL_PORT="$(read_env VLLM_LOCAL_PORT)"
OPENAI_API_KEY="$(read_env OPENAI_API_KEY)"

curl -fsS \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  "http://127.0.0.1:${VLLM_LOCAL_PORT:-$VLLM_PORT}/v1/models"
