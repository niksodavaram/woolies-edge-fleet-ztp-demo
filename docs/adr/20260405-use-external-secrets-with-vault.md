# ADR: Use External Secrets Operator with HashiCorp Vault

## Status
Accepted

## Context and Problem Statement
The platform needs a secure, auditable way to manage secrets (pull secrets, API tokens, credentials) for ~1,000 store clusters.  
We must avoid storing secrets in Git while still integrating with GitOps workflows.

## Decision Drivers
- No secrets in Git (even encrypted) to keep repos shareable and low-risk
- Centralised, audited, role-based secret management
- Compatibility with OpenShift and ArgoCD
- Simple model for store-specific secrets at scale

## Considered Options
- Sealed Secrets (encrypted secrets in Git)
- SOPS-encrypted files in Git
- External Secrets Operator (ESO) with HashiCorp Vault

## Decision Outcome
Chosen option: **External Secrets Operator with HashiCorp Vault**

### Consequences (Positive)
- Secrets never live in Git, only references do
- Vault audit logs show exactly which store pulled which secret and when
- Same Vault instance used for other platforms (central clusters, CI/CD)
- Per-store scoping via Vault paths and ESO `ClusterSecretStore`

### Consequences (Negative)
- Additional components to run and operate (Vault + ESO)
- Requires secure bootstrap and auth configuration for store clusters
- ESO/Vault outages can impact secret refresh behaviour

## Pros and Cons of the Options

### External Secrets + Vault
- Good: Strong separation between config (Git) and secrets (Vault)
- Good: Fine-grained RBAC via Vault policies and Kubernetes auth
- Bad: Operational overhead, needs HA and backup of Vault

### Sealed Secrets
- Good: Simple developer workflow, Git as single “source of everything”
- Bad: Secrets still live (encrypted) in Git, key rotation is painful at 1,000+ stores

### SOPS
- Good: Flexible tooling, supports multiple KMS backends
- Bad: Still stores encrypted secrets in Git, more tooling for developers

## Confirmation
- All `Secret` manifests in repos will be replaced by `ExternalSecret` or removed.
- Vault policy files and ESO manifests are stored alongside cluster manifests.
- Regular security audits will validate no secrets are present in Git history.