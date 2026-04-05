# ============================================================
# HashiCorp Vault Policy — woolies-edge-fleet
# Principle of least privilege — store nodes only read their
# own secrets; platform team has broader write access
# ============================================================

# Edge store nodes — read only
path "secret/data/woolies/ocp/*" {
  capabilities = ["read"]
}

path "secret/data/woolies/dynatrace/*" {
  capabilities = ["read"]
}

path "secret/data/woolies/splunk/*" {
  capabilities = ["read"]
}

path "secret/data/woolies/registry/*" {
  capabilities = ["read"]
}

# Per-store secrets (namespaced by store-id)
path "secret/data/woolies/stores/+/*" {
  capabilities = ["read"]
}

# Platform team — full CRUD on woolies secrets
path "secret/data/woolies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# PKI — store nodes can request TLS certs
path "pki/issue/woolies-internal" {
  capabilities = ["create", "update"]
}

# Auth — Kubernetes auth login
path "auth/kubernetes/login" {
  capabilities = ["create", "read"]
}
