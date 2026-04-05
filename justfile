set shell := ["bash", "-euo", "pipefail", "-c"]

public_files := ".env.example README.md compose.yaml scripts systemd"

lint-privacy:
  @echo "Checking public files for privacy leaks..."
  @if rg -nP '\b100\.(?!xxx\.xxx\.xxx\b)\d{1,3}\.\d{1,3}\.\d{1,3}\b' {{public_files}}; then \
    echo; \
    echo "lint-privacy failed: found a real tailnet-style IP in public files."; \
    exit 1; \
  fi
  @echo "lint-privacy passed"
