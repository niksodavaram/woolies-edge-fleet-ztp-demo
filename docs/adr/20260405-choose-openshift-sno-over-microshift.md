# ADR: Choose OpenShift SNO over MicroShift for Store Edge

## Status
Accepted

## Context and Problem Statement
We need a Kubernetes-based platform for ~1,000 Woolworths stores running on Dell DTCP hardware.  
The platform must support: GitOps, multi-tenancy, KubeVirt (Windows bridge), enterprise support, and full OpenShift ecosystem integration.

## Decision Drivers
- Native support for KubeVirt to host legacy Windows workloads during migration
- Consistent control plane features with central OpenShift clusters
- Enterprise-grade support from Red Hat (24x7, certified integrations)
- Minimise divergence between edge and core platform stacks
- Clear upgrade and lifecycle management story

## Considered Options
- OpenShift Single Node (SNO)
- MicroShift
- Vanilla Kubernetes (kubeadm, Talos, etc.)

## Decision Outcome
Chosen option: **OpenShift Single Node (SNO)**

### Consequences (Positive)
- Same APIs, operators, and lifecycle as core OpenShift clusters
- First-class integration with ArgoCD, External Secrets Operator, Dynatrace, Splunk
- KubeVirt supported and tested pattern on OpenShift edge
- Reuse existing platform engineering knowledge (NAB/Woolies teams)

### Consequences (Negative)
- Higher resource footprint than MicroShift (CPU/RAM) per store
- More complex upgrade process than a minimal K8s distro
- Licensing and subscription cost vs. purely upstream Kubernetes

## Pros and Cons of the Options

### OpenShift SNO
- Good: Full OpenShift feature set, consistent with central clusters
- Good: Supported KubeVirt pattern for Windows VMs
- Good: Works well with GitOps, operators, and enterprise tooling
- Bad: Heavier footprint, needs carefully sized Dell DTCP hardware
- Bad: Requires subscription and RH support contracts

### MicroShift
- Good: Lightweight footprint, more suitable for very small edge devices
- Good: Uses familiar OpenShift APIs for developers
- Bad: Limited compared to full OpenShift (operators, ecosystem)
- Bad: Additional platform patterns to manage vs. central clusters

### Vanilla Kubernetes
- Good: Maximal flexibility, no vendor lock-in
- Good: Potentially lower licensing cost
- Bad: You must assemble and maintain all integrations (GitOps, secrets, observability)
- Bad: No single vendor support, higher ops burden

## Confirmation
- The store SNO clusters will run the same version as central OpenShift.
- KubeVirt for Windows checkout-app will be tested in P1/P2 before scaling.
- Platform SRE runbooks will assume OpenShift semantics across environments.