# ADR-001 — SNO at large supermarkets, MicroShift at Metro/liquor stores

**Status:** Accepted  
**Date:** 2025-04-07  
**Author:** Nireekshan Sodavaram  
**Reviewers:** Platform team, Store Ops

---

## Context

WooliesX is migrating 3,000+ stores from Windows/VMware to a RHEL-based container platform.
Stores vary significantly in size, hardware capacity, and workload requirements.
Two OpenShift-family options are available for edge deployments:

- **Red Hat OpenShift Single Node (SNO):** Full OCP on one node. Minimum 8 vCPU / 16 GB RAM.
  Includes OpenShift Virtualization (KubeVirt), full operator framework, web console.
- **Red Hat MicroShift:** Lightweight Kubernetes derived from OCP. Minimum 2 CPU / 2 GB RAM.
  Intentionally excludes CVO, MCO, web console, monitoring stack. Includes: Kubernetes API,
  CRI-O, OpenShift Routes, SCCs, LVMS, ACM klusterlet.

---

## Decision

| Store type | Platform | RAM | Count | Reason |
|---|---|---|---|---|
| Large supermarket | **SNO** | 16 GB | ~800 | Needs KubeVirt for Windows bridge during P1–P3 migration |
| Metro / convenience | **MicroShift** | 8 GB | ~1,400 | Sufficient for all store workloads; lighter footprint |
| Liquor / specialist | **MicroShift** | 4 GB | ~800 | Minimal hardware; no Windows bridge needed |

**The rule:** if the store requires the KubeVirt Windows bridge during migration → **SNO**.
All other stores → **MicroShift**.

---

## Rationale

### Why SNO at large supermarkets

1. **KubeVirt requirement.** OpenShift Virtualization (KubeVirt) requires full OCP — it is not
   available in MicroShift. During migration phases P1–P3, the Windows checkout application must
   run as a KubeVirt VM inside the cluster to allow parallel operation. Large supermarkets have the
   hardware capacity (16 GB+ RAM) to support SNO + KubeVirt simultaneously.

2. **Hardware is available.** Large format stores run full-size servers. The 16 GB RAM minimum
   for SNO is met. Forcing MicroShift here would offer no benefit.

3. **Consistent API surface.** SNO uses the same OCP API as the central hub cluster. This
   simplifies workload manifests — no need to account for MicroShift API gaps.

### Why MicroShift at Metro and liquor stores

1. **Resource constraints.** Metro and liquor stores run compact edge servers (4–8 GB RAM).
   SNO requires 16 GB — this would force expensive hardware upgrades across ~2,200 stores.
   MicroShift runs comfortably on 4 GB.

2. **No Windows bridge needed.** Metro and liquor stores have simpler workload profiles —
   fewer legacy Windows dependencies. Containers can be deployed directly without a KubeVirt bridge.

3. **Intentional feature limitations are acceptable.** MicroShift excludes CVO, MCO, web console
   and the monitoring stack — all replaced by:
   - CVO/MCO → ostree image mode (RHEL Image Builder manages OS updates)
   - Web console → ACM fleet dashboard + `oc` CLI
   - Monitoring stack → OpenTelemetry → Thanos (fleet-wide observability)
   - OLM → optional from MicroShift 4.15, installable as RPM if needed

4. **Same fleet management.** MicroShift includes the ACM klusterlet — it registers with the
   central ACM hub identically to an SNO cluster. ArgoCD ApplicationSet, Vault + ESO, and
   Prometheus remote_write all work identically on both platforms.

---

## Options Considered

| Option | Rejected because |
|---|---|
| MicroShift everywhere | Cannot run KubeVirt — breaks Windows bridge strategy at large stores |
| SNO everywhere | 16 GB RAM minimum is too expensive for 2,200 Metro/liquor stores |
| SNO + KubeVirt everywhere | Unacceptable hardware cost at Metro/liquor scale |
| Third-party K8s (k3s, k0s) | Loses ACM klusterlet native integration; not Red Hat supported |

---

## Consequences

**Positive:**
- Optimal resource usage per store tier
- KubeVirt Windows bridge available exactly where needed
- Both platforms share the same ACM/ArgoCD/Vault/observability pipeline
- MicroShift stores can be upgraded to SNO in future if capacity increases

**Negative:**
- Two platforms to manage (mitigated: same GitOps pipeline, same RHEL base, same ACM klusterlet)
- Workload manifests must be tested on both SNO and MicroShift
- SNO image is larger (~120 GB) vs MicroShift (~10 GB) — Image Builder handles this per tier

---

## Review date

April 2026 — review if MicroShift adds OpenShift Virtualization support (tracking: USHIFT-4521).
