#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"
PROJECT_FILE="../04-secrets-cicd/argo-cd/project-woolies-edge-fleet.yaml"
ROOT_APP_FILE="../04-secrets-cicd/argo-cd/app-of-apps.yaml"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== [01] Applying Argo CD Project and App-of-Apps on hub ===${NC}"

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

# Check namespace
if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
  echo -e "${RED}Namespace '${NAMESPACE}' does not exist. Run install-argocd.sh first.${NC}"
  exit 1
fi

# Check files
if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo -e "${RED}Project file not found: ${PROJECT_FILE}${NC}"
  exit 1
fi

if [[ ! -f "${ROOT_APP_FILE}" ]]; then
  echo -e "${RED}Root app-of-apps file not found: ${ROOT_APP_FILE}${NC}"
  exit 1
fi

echo -e "${GREEN}Applying Argo CD Project: ${PROJECT_FILE}${NC}"
kubectl apply -n "${NAMESPACE}" -f "${PROJECT_FILE}"

echo -e "${GREEN}Applying Argo CD App-of-Apps: ${ROOT_APP_FILE}${NC}"
kubectl apply -n "${NAMESPACE}" -f "${ROOT_APP_FILE}"

echo -e "${GREEN}Argo CD Project and App-of-Apps applied successfully.${NC}"
echo -e "${YELLOW}Open the Argo CD UI and look for 'woolies-fleet-root'.${NC}"