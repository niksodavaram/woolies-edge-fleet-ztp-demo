# Phased Migration Runbook
## Windows/VMware on Dell DTCP → RHEL 9 + OpenShift SNO

This runbook governs the controlled migration of Woolworths store hardware
from legacy Windows Server / VMware ESXi stacks to RHEL 9 + OpenShift SNO,
using KubeVirt as a Windows bridge during transition.

---

## Phase Overview

```
P0: Foundation       → Golden Image built & validated
P1: Pilot ZTP        → 5 stores, co-existence (Win + RHEL)
P2: Fleet Bootstrap  → 100 stores, Windows in KubeVirt
P3: Full GitOps      → 1000 stores, ArgoCD-managed
P4: Decommission     → VMware/Windows retired
```

---

## Phase 0 — Foundation (Weeks 1–2)

### Objectives
- Build and validate RHEL 9 Golden Image on Dell DTCP hardware
- Validate `image.toml` TOML manifest drives correct package set
- Confirm CIS Level 2 benchmark passes via OpenSCAP scan

### Steps
```bash
# Build Golden Image
cd 00-provisioning/packer
packer validate rhel9-edge.pkr.hcl
packer build -var-file=vars/store-prod.pkrvars.hcl rhel9-edge.pkr.hcl

# Scan for CIS compliance
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_server_l2 \
  --results /tmp/cis-scan-result.xml \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-xccdf.xml

# Validate TOML manifest with RHEL Image Builder
composer-cli blueprints push 00-provisioning/image-metadata/image.toml
composer-cli blueprints depsolve woolies-rhel9-edge
```

### Exit Criteria
- [ ] Packer build completes without errors
- [ ] CIS Level 2 scan score ≥ 85%
- [ ] QCOW2 image uploaded to internal registry
- [ ] `image.toml` provenance fields populated

---

## Phase 1 — Pilot ZTP (Weeks 3–4)

### Objectives
- Deploy 5 pilot stores via Kickstart ZTP
- RHEL 9 + OCP SNO installed; Windows VMs imported to KubeVirt (co-existence)
- Validate ArgoCD sync, Vault secrets injection, Dynatrace telemetry

### Steps
```bash
# Bootstrap pilot stores
ansible-playbook 01-bootstrap/site-bootstrap.yml \
  -i 01-bootstrap/inventory/hosts.ini \
  --limit phase_p1

# Deploy OpenShift SNO on pilot stores
for store in store-003 store-201; do
  cd 02-infrastructure/manifests/overlays/$store
  openshift-install agent create image --dir .
  # Boot Dell DTCP from generated ISO
done

# Import Windows VM disk to KubeVirt PVC
virtctl image-upload pvc checkout-app-windows-pvc \
  --image-path=/backups/checkout-app-v3.2.vmdk \
  --size=80Gi \
  --namespace=woolies-legacy

# Apply KubeVirt Windows VM manifest
kubectl apply -f 03-workloads/legacy-windows/checkout-app.yaml
```

### TOML Migration Phase Update
```bash
# Update image.toml to reflect P1 completion
sed -i 's/current = "P0"/current = "P1"/' \
  00-provisioning/image-metadata/image.toml
git add . && git commit -m "chore: advance migration phase to P1 for pilot stores"
```

### Exit Criteria
- [ ] 5 stores running OCP SNO (healthy)
- [ ] Windows checkout-app running in KubeVirt (no functional regression)
- [ ] ArgoCD `store-00x-*` apps in `Synced/Healthy`
- [ ] Dynatrace shows store telemetry
- [ ] Vault secrets ESO-injected (no secrets in Git)

---

## Phase 2 — Fleet Bootstrap (Weeks 5–8)

### Objectives
- Scale to 100 stores via Ansible automation
- All Windows VMs running on KubeVirt
- Automated nightly CIS compliance reports via ArgoCD

### Steps
```bash
# Bulk bootstrap — all Phase P2 stores
ansible-playbook 01-bootstrap/site-bootstrap.yml \
  -i 01-bootstrap/inventory/hosts.ini \
  --limit phase_p2 \
  --forks 20          # Parallel — 20 stores simultaneously

# Generate store ArgoCD app manifests at scale
# (Use the store-generator Helm chart or scripted loop)
for store_id in $(cat stores-p2.txt); do
  envsubst < 04-secrets-cicd/argo-cd/stores/store-template.yaml \
    > 04-secrets-cicd/argo-cd/stores/${store_id}-app.yaml
done
git add . && git commit -m "feat: add ArgoCD apps for 100 P2 stores"
```

---

## Phase 3 — Full GitOps (Weeks 9–12)

### Objectives
- All 1,000 stores under ArgoCD control
- Full observability via Dynatrace + Splunk
- Zero manual SSH — all changes via Git PRs

---

## Phase 4 — Decommission (Weeks 13–16)

### Objectives
- Containerise checkout-app (remove KubeVirt dependency)
- Decommission VMware ESXi licenses
- Archive Windows VM PVCs (90-day retention per policy)

### TOML Final Update
```toml
# image.toml — final state after P4
[migration]
  current = "P4"
  kubevirt_bridge = false  # Windows VMs decommissioned
```

---

## Rollback Procedure

If any phase gate fails:

1. ArgoCD auto-sync rolls back to last `Healthy` commit
2. Windows KubeVirt VM remains running (no data loss)
3. Ansible re-run with `--tags hardening` fixes config drift
4. Escalate to platform team if SNO API unreachable (break-glass via `store-admin`)
