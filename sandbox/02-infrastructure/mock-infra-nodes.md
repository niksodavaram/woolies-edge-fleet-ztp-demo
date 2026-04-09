# 02-infrastructure – Mocked Infra Notes (Sandbox)

In the **real** Woolies Edge Fleet solution, this phase provisions the actual infrastructure:

- RHEL 9 / SNO / MicroShift clusters (on bare metal, vSphere, or cloud).
- Network, storage, and platform services required before workloads.
- Typically driven by `02-infrastructure/` manifests plus external tools (IPI/AGENT, RHACM, Terraform, etc.).

In the **sandbox**, we do **not** create real OpenShift / MicroShift clusters because that would be too heavy and slow for a 25‑minute demo. Instead:

- We treat the k3d clusters created in `sandbox/00-provisioning/` as **already-provisioned infra**.
- We only **explain** what would happen here in production and how it maps.

## How the sandbox maps to real 02-infrastructure

- **Real environment**
  - Uses `02-infrastructure/manifests/` (base + overlays) to generate:
    - `install-config.yaml`
    - AgentClusterInstall / AgentConfig
    - Per-store overlays for IPs, hostnames, MACs, machineNetwork.
  - Creates SNO / MicroShift clusters at each edge site.
  - May use ACM/Hub or OpenShift IPI/AI to drive installs.

- **Sandbox environment**
  - Uses `k3d cluster create hub` and `k3d cluster create edge-1..N` as stand-ins for “infra ready”.
  - Skips real OpenShift install to keep the lab lightweight.
  - From the perspective of later phases (03-workloads, 04-secrets-cicd, 05-migration), the k3d clusters behave like already-provisioned edge clusters.

## Story to tell in docs / interviews

- “In production, 02-infrastructure provisions real SNO / MicroShift clusters using the manifests under 02-infrastructure and tools like ACM or OpenShift Installer.”
- “In the sandbox, we mock that layer with k3d clusters so that reviewers can experience the GitOps/ZTP flow without needing bare metal or full OpenShift installs.”
- “Everything from 03-workloads onward is **identical in pattern** between the k3d sandbox and real edge clusters – only the infrastructure provider changes.”

For a real deployment, this folder would also include:

- Terraform / Ansible glue to drive OpenShift or MicroShift installs.
- Network and storage definitions (VLANs, LVMS layout, etc.).
- Integration points with the `openstack-mcp-infra-edge-governance-layer` repo for OpenStack-based sites.