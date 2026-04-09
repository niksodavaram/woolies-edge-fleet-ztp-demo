#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}=== [03] Running InSpec CIS RHEL9 profile (sandbox) ===${NC}"

if ! command -v inspec >/dev/null 2>&1; then
  echo -e "${RED}inspec not found. Install InSpec before running this script.${NC}"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}/tests/inspec/cis-rhel9"

inspec exec . --target local://

echo -e "${GREEN}InSpec CIS RHEL9 checks completed (see summary above).${NC}"