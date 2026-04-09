#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"
STORE_ID="store-0001"

PROFILE_V1_FILE="../04-secrets-cicd/argo-cd/stores/${STORE_ID}/store-0001-profile-v1.yaml"
PROFILE_V2_FILE="../04-secrets-cicd/argo-cd/stores/${STORE_ID}/store-0001-profile-v2.yaml"

TARGET_PROFILE="${TARGET_PROFILE:-v2}"   # default switch to v2
APP_NAME="${APP_NAME:-woolies-${STORE_ID}-apps}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== [05] Switching ${STORE_ID} profile to '${TARGET_PROFILE}' ===${NC}"

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

# Decide which profile file to apply
case "${TARGET_PROFILE}" in
  v1)
    PROFILE_FILE="${PROFILE_V1_FILE}"
    ;;
  v2)
    PROFILE_FILE="${PROFILE_V2_FILE}"
    ;;
  *)
    echo -e "${RED}Unknown TARGET_PROFILE '${TARGET_PROFILE}'. Use v1 or v2.${NC}"
    exit 1
    ;;
esac

if [[ ! -f "${PROFILE_FILE}" ]]; then
  echo -e "${RED}Profile file not found: ${PROFILE_FILE}${NC}"
  exit 1
fi

echo -e "${GREEN}Applying Argo CD Application for ${STORE_ID} using profile '${TARGET_PROFILE}'...${NC}"
kubectl apply -n "${NAMESPACE}" -f "${PROFILE_FILE}"

echo -e "${GREEN}Application applied. If you have argocd CLI, you can force sync:${NC}"
echo -e "  argocd app sync ${APP_NAME}"
echo -e "${YELLOW}In the UI, watch ${APP_NAME} roll from profile v1 to v2 (migration).${NC}"