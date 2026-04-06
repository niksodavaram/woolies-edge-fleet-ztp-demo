# tests/conftest/workloads/secrets_test.rego
package workloads.secrets

import future.keywords.in

test_vault_secret_store_used {
  input.kind == "ExternalSecret"
  input.spec.secretStoreRef.kind in {"ClusterSecretStore","SecretStore"}
  contains(lower(input.spec.secretStoreRef.name), "vault")
}
test_refresh_interval_non_zero {
  input.kind == "ExternalSecret"
  input.spec.refreshInterval != "0"; input.spec.refreshInterval != ""
}
test_vault_k8s_auth {
  input.kind in {"SecretStore","ClusterSecretStore"}
  input.spec.provider.vault.auth.kubernetes != null
}
test_vault_path_namespaced {
  input.kind == "ExternalSecret"
  some data in input.spec.data
  startswith(data.remoteRef.key, "secret/woolies/")
}
deny_raw_secret_data[msg] {
  input.kind == "Secret"
  input.type != "kubernetes.io/service-account-token"
  count(input.data) > 0
  msg := sprintf("Secret '%v/%v' has inline data — use ESO",
                 [input.metadata.namespace, input.metadata.name])
}