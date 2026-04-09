#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== [01] Installing Argo CD into hub cluster (namespace: ${NAMESPACE}) ===${NC}"

# Check kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${RED}kubectl not found. Please install kubectl before running this script.${NC}"
  exit 1
fi

# Ensure we’re pointing at hub
CURRENT_CONTEXT="$(kubectl config current-context || true)"
if [[ "${CURRENT_CONTEXT}" != "k3d-hub" ]]; then
  echo -e "${YELLOW}Current context is '${CURRENT_CONTEXT}', switching to 'k3d-hub'.${NC}"
  kubectl config use-context k3d-hub
fi

# Create namespace if needed
if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
  echo -e "${GREEN}Creating namespace '${NAMESPACE}'...${NC}"
  kubectl create namespace "${NAMESPACE}"
else
  echo -e "${YELLOW}Namespace '${NAMESPACE}' already exists. Skipping creation.${NC}"
fi

# Install Argo CD using the official manifest
echo -e "${GREEN}Applying Argo CD install manifest...${NC}"
kubectl apply -n "${NAMESPACE}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${GREEN}Waiting for Argo CD server deployment to be ready...${NC}"
kubectl wait --namespace "${NAMESPACE}" \
  --for=condition=available \
  --timeout=300s \
  deployment/argocd-server

echo -e "${GREEN}Argo CD installed successfully in namespace '${NAMESPACE}'.${NC}"
echo -e "${YELLOW}You can port-forward the UI with:${NC}"
echo -e "  kubectl -n ${NAMESPACE} port-forward svc/argocd-server 8080:80"
echo -e "${YELLOW}Next: apply your project and app-of-apps from 04-secrets-cicd/argo-cd/.${NC}"