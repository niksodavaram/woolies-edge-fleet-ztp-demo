#!/usr/bin/env bash
set -euo pipefail

EDGE_COUNT="${EDGE_COUNT:-3}"   # default 3 edges, override with EDGE_COUNT=4 ./create-edge-k3d.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== [00] Creating ${EDGE_COUNT} k3d edge clusters ===${NC}"

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

for i in $(seq 1 "${EDGE_COUNT}"); do
  CLUSTER_NAME="edge-${i}"

  if k3d cluster list | grep -q "^${CLUSTER_NAME}\b"; then
    echo -e "${YELLOW}Cluster '${CLUSTER_NAME}' already exists. Skipping.${NC}"
    continue
  fi

  echo -e "${GREEN}--- Creating edge cluster: ${CLUSTER_NAME} ---${NC}"

  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 1 \
    --k3s-arg "--disable=traefik@server:0" \
    --wait

  echo -e "${GREEN}Cluster '${CLUSTER_NAME}' created.${NC}"
done

echo -e "${GREEN}All requested edge clusters created.${NC}"
echo -e "${YELLOW}Use 'kubectl config get-contexts' to see them (contexts named k3d-edge-1, k3d-edge-2, ...).${NC}"
echo -e "${GREEN}Next: install Argo CD on hub and wire these edges via your Argo/ACM config.${NC}"