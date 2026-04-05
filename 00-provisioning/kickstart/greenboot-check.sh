#!/bin/bash
# /etc/greenboot/check/required.d/40-woolies-store-health.sh
#
# Woolworths store edge node — greenboot health checks
# If ANY check fails: greenboot triggers ostree rollback to previous good image
# No engineer visit required. Rollback completes in under 5 minutes.
#
# Docs: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/composing_installing_and_managing_rhel_for_edge_images/proc_adding-greenboot-health-checks_composing-installing-managing-rhel-for-edge-images

set -euo pipefail

LOGPREFIX="[woolies-greenboot]"
TIMEOUT=120   # seconds to wait for MicroShift API

log() { echo "${LOGPREFIX} $*" | systemd-cat -t greenboot -p info; echo "${LOGPREFIX} $*"; }
fail() { echo "${LOGPREFIX} FAIL: $*" | systemd-cat -t greenboot -p err; echo "${LOGPREFIX} FAIL: $*"; exit 1; }

# ── Check 1: MicroShift API server reachable ─────────────────────────────────
log "Checking MicroShift API server..."
ELAPSED=0
until curl -skf https://localhost:6443/readyz --cacert /var/lib/microshift/resources/kubeadmin/kubeconfig &>/dev/null; do
  sleep 5; ELAPSED=$((ELAPSED+5))
  [[ $ELAPSED -ge $TIMEOUT ]] && fail "MicroShift API server not ready after ${TIMEOUT}s"
done
log "MicroShift API server: OK"

# ── Check 2: Required system pods running ────────────────────────────────────
log "Checking required system pods..."
export KUBECONFIG=/var/lib/microshift/resources/kubeadmin/kubeconfig

REQUIRED_NS=("openshift-dns" "openshift-ingress" "openshift-ovn-kubernetes" "openshift-storage")
for ns in "${REQUIRED_NS[@]}"; do
  NOTREADY=$(oc get pods -n "$ns" --no-headers 2>/dev/null \
    | grep -v -E "Running|Completed|Succeeded" | wc -l)
  [[ $NOTREADY -gt 0 ]] && fail "Unhealthy pods in $ns (${NOTREADY} not ready)"
  log "Namespace $ns: OK"
done

# ── Check 3: Store workloads present (after P2 onward) ───────────────────────
PHASE=$(grep -A2 '\[woolies.migration\]' /etc/woolies/image.toml 2>/dev/null \
  | grep current_phase | cut -d'"' -f2 || echo "P0")

if [[ "$PHASE" != "P0" && "$PHASE" != "P1" ]]; then
  log "Phase $PHASE — checking store workloads..."
  for ns in ("store-pos" "store-inventory" "store-cold-chain"); do
    oc get pods -n "$ns" &>/dev/null || fail "Namespace $ns missing — store workloads not deployed"
    log "Namespace $ns: present"
  done
fi

# ── Check 4: Disk space sufficient ───────────────────────────────────────────
log "Checking disk space..."
ROOT_USE=$(df / --output=pcent | tail -1 | tr -d ' %')
VAR_USE=$(df /var --output=pcent | tail -1 | tr -d ' %')
[[ $ROOT_USE -gt 85 ]] && fail "Root filesystem usage ${ROOT_USE}% > 85% threshold"
[[ $VAR_USE  -gt 85 ]] && fail "/var usage ${VAR_USE}% > 85% threshold"
log "Disk space: root=${ROOT_USE}% var=${VAR_USE}% — OK"

# ── Check 5: SELinux enforcing ────────────────────────────────────────────────
log "Checking SELinux mode..."
MODE=$(getenforce)
[[ "$MODE" != "Enforcing" ]] && fail "SELinux is ${MODE} — expected Enforcing"
log "SELinux: Enforcing — OK"

# ── Check 6: Network connectivity to regional hub ────────────────────────────
log "Checking connectivity to regional hub..."
HUB=$(cat /etc/woolies/node-metadata.json 2>/dev/null | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('regional_hub','hub.woolies.internal'))" \
  2>/dev/null || echo "hub.woolies.internal")
ping -c2 -W5 "$HUB" &>/dev/null || log "WARN: Regional hub $HUB unreachable — offline-first mode (non-fatal)"

log "All greenboot checks PASSED — store node is healthy"
exit 0
