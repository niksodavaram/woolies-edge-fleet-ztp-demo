#!/usr/bin/env bash
set -euo pipefail

STORE_COUNT="${STORE_COUNT:-3}"   # default 3 stores

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== [03] Creating edge store namespaces on hub ===${NC}"

# Check kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${RED}kubectl not found. Please install kubectl before running this script.${NC}"
  exit 1
fi

# Ensure context is hub
CURRENT_CONTEXT="$(kubectl config current-context || true)"
if [[ "${CURRENT_CONTEXT}" != "k3d-hub" ]]; then
  echo -e "${YELLOW}Current context is '${CURRENT_CONTEXT}', switching to 'k3d-hub'.${NC}"
  kubectl config use-context k3d-hub
fi

for i in $(seq 1 "${STORE_COUNT}"); do
  NS="woolies-store-$(printf '%04d' "${i}")"

  if kubectl get ns "${NS}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Namespace '${NS}' already exists. Skipping.${NC}"
    continue
  fi

  echo -e "${GREEN}Creating namespace '${NS}'...${NC}"
  kubectl create namespace "${NS}"

  kubectl label namespace "${NS}" \
    store.id="${NS}" \
    store.role="edge" \
    environment="dev" \
    --overwrite
done

echo -e "${GREEN}Edge store namespaces created.${NC}"
echo -e "${YELLOW}Make sure your Argo CD store Applications target these namespaces.${NC}"