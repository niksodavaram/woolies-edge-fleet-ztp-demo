# ADR: Use KubeVirt as the Windows Bridge During Migration

## Status
Accepted

## Context and Problem Statement
Existing store workloads (checkout-app, POS integrations) run on Windows VMs on VMware ESXi hosted on Dell DTCP.  
We need a safe migration path to RHEL + OpenShift without a risky big-bang cutover.

## Decision Drivers
- Zero or minimal downtime for checkout-app
- Ability to roll back quickly if OpenShift rollout has issues
- Operate Windows workloads under the same GitOps and observability model
- Avoid dual-stack operational complexity (VMware cluster + OpenShift cluster)

## Considered Options
- Maintain VMware ESXi and run OpenShift alongside
- Lift-and-shift Windows VMs into cloud (Azure/AWS)
- Run Windows VMs via KubeVirt on the SNO nodes

## Decision Outcome
Chosen option: **Run Windows VMs via KubeVirt on SNO nodes**

### Consequences (Positive)
- Single control plane: everything (Linux containers + Windows VMs) under OpenShift
- Windows lifecycle (patching, config) can be automated via GitOps and Ansible/WinRM
- Simple rollback: keep PVC snapshots and VM definitions in Git
- Reduced hardware and licensing complexity over time (VMware decommission)

### Consequences (Negative)
- KubeVirt adds complexity to cluster operations
- Requires careful sizing of Dell DTCP for CPU/RAM/IOPS
- Windows performance may differ vs bare VMware until tuned

## Pros and Cons of the Options

### KubeVirt on SNO
- Good: Unified platform, Windows + Linux workloads visible in the same dashboards
- Good: Fits phased migration (P1–P4) with clear decommission point
- Bad: Requires KubeVirt expertise and additional monitoring

### Keep VMware alongside OpenShift
- Good: Familiar operational model, minimal change for Windows
- Bad: Two platforms to run at every store, larger hardware + license footprint
- Bad: Harder GitOps story; drift between platforms likely

### Cloud lift-and-shift
- Good: Simplifies store hardware, moves risk to cloud
- Bad: Store connectivity requirements (latency, availability)
- Bad: Data sovereignty and network egress costs

## Confirmation
- KubeVirt VMs will be managed via Git (YAML manifests) and ArgoCD.
- Performance and reliability SLAs for checkout-app will be validated in P1/P2.
- KubeVirt usage will be removed in P4 when workloads are fully containerised.