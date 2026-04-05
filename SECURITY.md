# Security Policy

This repo demonstrates an **edge platform reference architecture**. Even
though it is a demo, we follow production-style security practices. [web:124][web:152][web:151][web:154]

## Secrets and credentials

- **Never** commit secrets, tokens, or private keys to this repo.
- All runtime secrets are expected to come from **HashiCorp Vault** via
  **External Secrets Operator (ESO)**.
- Example Vault paths (e.g. `secret/woolies/ocp/pull-secret`) are placeholders
  and must be adapted for real environments.

## Operating system hardening

- The RHEL 9 Golden Image is designed to meet **CIS Level 2** guidance:
  - SELinux `Enforcing`.
  - Auditing enabled (auditd).
  - Partitioning and sysctl tuned for security.
- Nodes are prepared for OpenShift SNO with required kernel modules and
  sysctl values, but not weakened beyond what SCCs expect.

## Container security

- Application containers are expected to:
  - Run as **non-root arbitrary UID** (OpenShift default behaviour).
  - Drop all Linux capabilities by default.
  - Avoid requiring privileged or host-mounted volumes unless explicitly noted.
- Deployment manifests should always define:
  - `securityContext.runAsNonRoot: true`
  - `securityContext.allowPrivilegeEscalation: false`
  - `securityContext.capabilities.drop: ["ALL"]`

## SCCs and build pipelines

- Build pipelines (Tekton/OpenShift Pipelines) should use a **dedicated
  ServiceAccount + custom SCC** with only the permissions needed to build
  and push images.
- Runtime workloads should use the **restricted** or equivalent SCC by default.

## Network and registry

- Edge clusters are designed for **limited or disconnected** environments:
  - OpenShift payloads and images are pulled from an internal mirror
    registry (e.g. `registry.woolies.internal:5000`).
  - Untrusted public registries should be blocked via cluster image config.
- NetworkPolicies should default-deny and allow only required flows
  (e.g. ArgoCD, Vault, metrics, MQTT/DDS).

## Reporting issues

This repo is a demo and not an official Woolworths or Red Hat product.
If you spot a security concern in the patterns shown here:

- Raise an issue in the repository with as much detail as possible, **without**
  including any real secrets or internal hostnames.
- For real environments, follow your organisation’s internal security
  reporting process.