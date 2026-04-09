#!/usr/bin/env bash
set -euo pipefail

NAMESPACE_ARGO="argocd"
NAMESPACE_DEMO="${NAMESPACE_DEMO:-woolies-store-0001}"

GIT_SECRET_NAME="${GIT_SECRET_NAME:-demo-git-credentials}"
REG_SECRET_NAME="${REG_SECRET_NAME:-demo-registry-credentials}"

GIT_USERNAME="${GIT_USERNAME:-demo-user}"
GIT_PASSWORD="${GIT_PASSWORD:-demo-token}"

REG_SERVER="${REG_SERVER:-registry-1.docker.io}"
REG_USERNAME="${REG_USERNAME:-demo-user}"
REG_PASSWORD="${REG_PASSWORD:-demo-password}"
REG_EMAIL="${REG_EMAIL:-demo@example.com}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== [04] Creating demo Git and registry secrets ===${NC}"

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

# Ensure namespaces exist
for NS in "${NAMESPACE_ARGO}" "${NAMESPACE_DEMO}"; do
  if ! kubectl get ns "${NS}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Namespace '${NS}' does not exist, creating it...${NC}"
    kubectl create ns "${NS}"
  fi
done

echo -e "${GREEN}Creating demo Git credentials secret in '${NAMESPACE_ARGO}'...${NC}"
kubectl -n "${NAMESPACE_ARGO}" delete secret "${GIT_SECRET_NAME}" >/dev/null 2>&1 || true
kubectl -n "${NAMESPACE_ARGO}" create secret generic "${GIT_SECRET_NAME}" \
  --from-literal=username="${GIT_USERNAME}" \
  --from-literal=password="${GIT_PASSWORD}"

echo -e "${GREEN}Creating demo image registry secret in '${NAMESPACE_DEMO}'...${NC}"
kubectl -n "${NAMESPACE_DEMO}" delete secret "${REG_SECRET_NAME}" >/dev/null 2>&1 || true
kubectl -n "${NAMESPACE_DEMO}" create secret docker-registry "${REG_SECRET_NAME}" \
  --docker-server="${REG_SERVER}" \
  --docker-username="${REG_USERNAME}" \
  --docker-password="${REG_PASSWORD}" \
  --docker-email="${REG_EMAIL}"

echo -e "${GREEN}Demo secrets created.${NC}"
echo -e "${YELLOW}Wire these names into your ExternalSecrets / Tekton tasks / ArgoCD repo secrets as needed.${NC}"