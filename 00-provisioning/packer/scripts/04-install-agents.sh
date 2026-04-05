#!/usr/bin/env bash
# Install observability agents: Dynatrace OneAgent + Splunk UF
# Agents are pre-baked into the Golden Image for ZTP stores
set -euo pipefail

echo "[woolies-agents] Installing observability agents..."

# Dynatrace OneAgent — silent install, activates on first boot
# Token injected at runtime via cloud-init / Ansible (not baked in)
if [[ -f /tmp/Dynatrace-OneAgent-Linux.sh ]]; then
  chmod +x /tmp/Dynatrace-OneAgent-Linux.sh
  /tmp/Dynatrace-OneAgent-Linux.sh \
    --set-infra-only=false \
    --set-app-log-content-access=true \
    --set-system-logs-access-enabled=true \
    APP_LOG_CONTENT_ACCESS=1
else
  echo "[woolies-agents] Dynatrace installer not found — will deploy via Ansible Day 1"
fi

# Splunk Universal Forwarder — configured to ship to central SIEM
if rpm -q splunkforwarder &>/dev/null; then
  echo "[woolies-agents] Splunk UF already installed"
else
  # Install from local repo mirror (no internet at stores during PXE)
  dnf install -y splunkforwarder 2>/dev/null || \
    echo "[woolies-agents] Splunk UF install deferred to Ansible bootstrap"
fi

echo "[woolies-agents] Agent installation complete."
