#!/usr/bin/env bash
set -euo pipefail

ROOT_APP_NAME="${ROOT_APP_NAME:-woolies-fleet-root}"
NAMESPACE="argocd"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"   # 15 minutes

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== [03] Waiting for Argo CD apps to sync and become healthy ===${NC}"

# Check argocd CLI
if ! command -v argocd >/dev/null 2>&1; then
  echo -e "${RED}argocd CLI not found. Please install it before running this script.${NC}"
  exit 1
fi

# Ensure context is hub for kubectl (argocd CLI uses server/login)
if command -v kubectl >/dev/null 2>&1; then
  CURRENT_CONTEXT="$(kubectl config current-context || true)"
  if [[ "${CURRENT_CONTEXT}" != "k3d-hub" ]]; then
    echo -e "${YELLOW}Current context is '${CURRENT_CONTEXT}', switching to 'k3d-hub'.${NC}"
    kubectl config use-context k3d-hub
  fi
fi

echo -e "${YELLOW}Syncing root app '${ROOT_APP_NAME}'...${NC}"
argocd app sync "${ROOT_APP_NAME}"

echo -e "${YELLOW}Waiting for root app '${ROOT_APP_NAME}' to be healthy (timeout: ${TIMEOUT_SECONDS}s)...${NC}"
argocd app wait "${ROOT_APP_NAME}" \
  --timeout "${TIMEOUT_SECONDS}" \
  --sync \
  --health

echo -e "${GREEN}Root app '${ROOT_APP_NAME}' is synced and healthy.${NC}"
echo -e "${YELLOW}If your root app creates child Applications (stores), they will now begin syncing.${NC}"