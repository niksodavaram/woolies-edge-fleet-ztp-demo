# tests/conftest/provisioning/image_toml_test.rego
# Run: conftest test 00-provisioning/image-metadata/image.toml \
#        --policy tests/conftest/provisioning
package provisioning.image

import future.keywords.in

# ── Required packages ────────────────────────────────────────────────────────
test_microshift_packages_present {
  required := {"microshift","microshift-selinux","microshift-networking","microshift-greenboot"}
  every pkg in required { pkg in input.packages.include }
}

test_security_packages_present {
  required := {"aide","auditd","openscap-scanner","scap-security-guide"}
  every pkg in required { pkg in input.packages.include }
}

test_observability_packages_present {
  required := {"prometheus-node-exporter","promtail"}
  every pkg in required { pkg in input.packages.include }
}

# ── Insecure packages excluded ───────────────────────────────────────────────
test_telnet_excluded      { "telnet"     in input.packages.exclude }
test_rsh_excluded         { "rsh"        in input.packages.exclude }
test_tftp_excluded        { "tftp"       in input.packages.exclude }
test_bluetooth_excluded   { "bluetooth"  in input.packages.exclude }

# ── Kernel hardening ─────────────────────────────────────────────────────────
test_selinux_enforcing_in_kernel {
  contains(input.customizations.kernel.append, "enforcing=1")
}
test_audit_enabled_in_kernel {
  contains(input.customizations.kernel.append, "audit=1")
}
test_serial_console_configured {
  contains(input.customizations.kernel.append, "console=ttyS0,115200")
}

# ── CIS filesystem partitioning ───────────────────────────────────────────────
test_separate_var_partition {
  some fs in input.customizations.filesystem
  fs.mountpoint == "/var"
  fs.minsize >= 21474836480   # 20 GB minimum for MicroShift writes
}
test_separate_tmp_partition {
  some fs in input.customizations.filesystem
  fs.mountpoint == "/tmp"
}
test_separate_microshift_data_partition {
  some fs in input.customizations.filesystem
  fs.mountpoint == "/var/lib/microshift"
}

# ── Services ─────────────────────────────────────────────────────────────────
test_microshift_service_enabled  { "microshift"             in input.customizations.services.enabled }
test_greenboot_enabled           { "greenboot-healthcheck"  in input.customizations.services.enabled }
test_bluetooth_service_disabled  { "bluetooth"              in input.customizations.services.disabled }

# ── Firewall ─────────────────────────────────────────────────────────────────
test_ssh_firewall_open { "ssh" in input.customizations.firewall.services.enabled }
test_telnet_blocked    { "telnet" in input.customizations.firewall.services.disabled }

test_microshift_api_port_open {
  some p in input.customizations.firewall.ports
  p.port == "6443"; p.protocol == "tcp"
}
test_mqtt_cold_chain_port_open {
  some p in input.customizations.firewall.ports
  p.port == "1883"; p.protocol == "tcp"
}

# ── Image metadata completeness ───────────────────────────────────────────────
test_version_semver       { regex.match(`^\d+\.\d+\.\d+$`, input.version) }
test_distro_is_rhel9      { input.distro == "rhel-9" }
test_cis_level2           { input["woolies.image"].cis_level == "level2" }
test_oscap_pass           { input["woolies.image"].oscap_pass == true }

# ── Migration metadata ────────────────────────────────────────────────────────
test_migration_phase_valid {
  input["woolies.migration"].current_phase in {"P0","P1","P2","P3","P4"}
}
test_kubevirt_bridge_is_bool  { is_boolean(input["woolies.migration"].kubevirt_bridge) }
test_store_tier_valid         { input["woolies.store"].tier in {"supermarket","metro","liquor"} }

# ── Disconnected-safe registry mirrors ───────────────────────────────────────
test_openshift_registry_mirrored {
  some src in input.customizations.imageContentSources
  src.source == "quay.io/openshift"
  some m in src.mirrors
  contains(m, "registry.woolies.internal")
}
test_ubi9_registry_mirrored {
  some src in input.customizations.imageContentSources
  src.source == "registry.access.redhat.com/ubi9"
  some m in src.mirrors
  contains(m, "registry.woolies.internal")
}