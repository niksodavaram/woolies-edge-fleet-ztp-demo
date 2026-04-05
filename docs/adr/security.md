# Security Policy

- Secrets must never be committed to Git.
- All credentials are stored in HashiCorp Vault and consumed via External Secrets Operator.
- Changes to `04-secrets-cicd/*` require security team review.
- SELinux is enforced on all nodes; workloads are expected to run under restricted SCC.