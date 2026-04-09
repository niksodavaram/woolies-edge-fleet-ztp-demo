#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}=== [05] Running Godog BDD scenarios (ZTP + migration) ===${NC}"

if ! command -v godog >/dev/null 2>&1; then
  echo -e "${RED}godog not found. Install it (e.g. 'go install github.com/cucumber/godog/v3@latest').${NC}"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}/tests/godog"

godog run

echo -e "${GREEN}BDD tests completed.${NC}"