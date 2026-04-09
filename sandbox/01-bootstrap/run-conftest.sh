#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}=== [01] Running Conftest (OPA) policy checks ===${NC}"

if ! command -v conftest >/dev/null 2>&1; then
  echo -e "${RED}conftest not found. Install it before running this script.${NC}"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

echo -e "${YELLOW}Checking provisioning artifacts...${NC}"
conftest test \
  --policy tests/conftest/provisioning \
  00-provisioning/image-builder/image.toml \
  00-provisioning/kickstart/*.ks

echo -e "${YELLOW}Checking infrastructure manifests...${NC}"
conftest test \
  --policy tests/conftest/infrastructure \
  02-infrastructure/manifests/**/*.yaml

echo -e "${YELLOW}Checking workload manifests...${NC}"
conftest test \
  --policy tests/conftest/workloads \
  03-workloads/**/*.yaml \
  04-secrets-cicd/**/*.yaml

echo -e "${GREEN}Conftest policy checks passed.${NC}"