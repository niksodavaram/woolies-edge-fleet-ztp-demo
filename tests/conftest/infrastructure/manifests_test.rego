# tests/conftest/infrastructure/manifests_test.rego
# Run: conftest test 02-infrastructure/manifests/ \
#        --policy tests/conftest/infrastructure --all-namespaces
package infrastructure.manifests

import future.keywords.in

# ── install-config.yaml ───────────────────────────────────────────────────────
test_base_domain_present       { input.baseDomain != "" }
test_fips_enabled              { input.fips == true }

# ── agent-config.yaml ────────────────────────────────────────────────────────
test_rendezvous_ip_present     { input.rendezvousIP != "" }
test_hosts_defined             { count(input.hosts) > 0 }
test_host_interface_has_mac {
  some host in input.hosts
  some iface in host.interfaces
  regex.match(`^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$`, iface.macAddress)
}

# ── Generic k8s manifest policy ───────────────────────────────────────────────
test_apiversion_present        { input.apiVersion != "" }
test_kind_present              { input.kind != "" }

deny_root_containers[msg] {
  some c in input.spec.template.spec.containers
  c.securityContext.runAsUser == 0
  msg := sprintf("Container '%v' must not run as root", [c.name])
}

deny_latest_image_tag[msg] {
  some c in input.spec.template.spec.containers
  endswith(c.image, ":latest")
  msg := sprintf("Container '%v' uses :latest — pin to digest", [c.name])
}

deny_privileged_containers[msg] {
  some c in input.spec.template.spec.containers
  c.securityContext.privileged == true
  msg := sprintf("Container '%v' must not be privileged", [c.name])
}

deny_secret_in_env[msg] {
  some c in input.spec.template.spec.containers
  some env in c.env
  lower(env.name) in {"password","secret","api_key","token","passwd"}
  env.value != ""
  msg := sprintf("Env '%v' in '%v' looks like a plaintext secret — use ESO", [env.name, c.name])
}

test_resource_limits_defined {
  input.kind in {"Deployment","DaemonSet","StatefulSet"}
  some c in input.spec.template.spec.containers
  c.resources.limits.memory != ""; c.resources.limits.cpu != ""
}

# ── ArgoCD Application ────────────────────────────────────────────────────────
test_argocd_app_has_sync_policy {
  input.kind == "Application"
  input.spec.syncPolicy != null
}
test_argocd_prune_enabled {
  input.kind == "Application"
  input.spec.syncPolicy.automated.prune == true
}
test_argocd_self_heal_enabled {
  input.kind == "Application"
  input.spec.syncPolicy.automated.selfHeal == true
}
test_appset_store_tier_generator {
  input.kind == "ApplicationSet"
  some gen in input.spec.generators
  gen.clusters.selector.matchLabels["woolies.store/tier"] != ""
}