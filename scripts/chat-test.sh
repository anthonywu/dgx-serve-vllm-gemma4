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

VLLM_PORT="$(read_env VLLM_PORT)"
VLLM_LOCAL_PORT="$(read_env VLLM_LOCAL_PORT)"
OPENAI_API_KEY="$(read_env OPENAI_API_KEY)"
SERVED_MODEL_NAME="$(read_env SERVED_MODEL_NAME)"

PROMPT="${1:-Write one short sentence confirming the API is working.}"
ESCAPED_PROMPT="${PROMPT//\\/\\\\}"
ESCAPED_PROMPT="${ESCAPED_PROMPT//\"/\\\"}"
ESCAPED_PROMPT="${ESCAPED_PROMPT//$'\n'/\\n}"
ESCAPED_PROMPT="${ESCAPED_PROMPT//$'\r'/\\r}"
ESCAPED_PROMPT="${ESCAPED_PROMPT//$'\t'/\\t}"

request_chat() {
  local base_url="$1"
  curl -fsS \
    "${base_url}/v1/chat/completions" \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
    \"model\": \"${SERVED_MODEL_NAME}\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"${ESCAPED_PROMPT}\"}
    ],
    \"max_tokens\": 96
  }"
}

LOCAL_BASE_URL="http://127.0.0.1:${VLLM_LOCAL_PORT:-$VLLM_PORT}"

if request_chat "$LOCAL_BASE_URL"; then
  exit 0
fi

if command -v docker >/dev/null 2>&1; then
  CONTAINER_IP="$(docker inspect gemma4-openai --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || true)"
  if [[ -n "${CONTAINER_IP}" ]]; then
    request_chat "http://${CONTAINER_IP}:8000"
    exit 0
  fi
fi

exit 1
