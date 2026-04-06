# tests/conftest/workloads/pos_test.rego
package workloads.pos

import future.keywords.in

test_pos_namespace_not_default {
  input.metadata.namespace != ""; input.metadata.namespace != "default"
}
test_image_from_internal_registry {
  input.kind in {"Deployment","DaemonSet"}
  some c in input.spec.template.spec.containers
  startswith(c.image, "registry.woolies.internal")
}
test_readiness_probe_defined {
  input.kind == "Deployment"
  some c in input.spec.template.spec.containers
  c.readinessProbe != null
}
test_pos_min_replicas        { input.kind == "Deployment"; input.spec.replicas >= 1 }
test_cpu_limit_set {
  input.kind in {"Deployment","DaemonSet"}
  some c in input.spec.template.spec.containers
  c.resources.limits.cpu != ""
}
test_mqtt_service_port_present {
  input.kind == "Service"
  some port in input.spec.ports
  port.port == 1883
}