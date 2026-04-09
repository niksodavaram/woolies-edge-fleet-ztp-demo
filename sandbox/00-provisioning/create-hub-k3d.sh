#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="hub"
API_PORT="6550"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== [00] Creating k3d hub cluster: ${CLUSTER_NAME} ===${NC}"

# Check k3d
if ! command -v k3d >/dev/null 2>&1; then
  echo -e "${RED}k3d not found. Please install k3d before running this script.${NC}"
  exit 1
fi

# Check docker
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}docker not found. Please install and start Docker before running this script.${NC}"
  exit 1
fi

# If cluster exists, skip create
if k3d cluster list | grep -q "^${CLUSTER_NAME}\b"; then
  echo -e "${YELLOW}Cluster '${CLUSTER_NAME}' already exists. Skipping creation.${NC}"
else
  k3d cluster create "${CLUSTER_NAME}" \
    --api-port "${API_PORT}" \
    --servers 1 \
    --agents 1 \
    --k3s-arg "--disable=traefik@server:0" \
    --wait

  echo -e "${GREEN}Cluster '${CLUSTER_NAME}' created.${NC}"
fi

# Point kubectl to this cluster
if command -v kubectl >/dev/null 2>&1; then
  kubectl config use-context "k3d-${CLUSTER_NAME}"
  echo -e "${GREEN}kubectl context switched to k3d-${CLUSTER_NAME}.${NC}"
else
  echo -e "${YELLOW}kubectl not found. Cluster is created, but kubectl context was not switched.${NC}"
fi

echo -e "${GREEN}Hub cluster ready. Next step: install Argo CD in sandbox/01-bootstrap/install-argocd.sh${NC}"