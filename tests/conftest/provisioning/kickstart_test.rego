# tests/conftest/provisioning/kickstart_test.rego
# Pre-process .ks to JSON: { "content": "<raw text>" }, then:
# Run: conftest test --policy tests/conftest/provisioning kickstart.json
package provisioning.kickstart

import future.keywords.in

ks := input.content

# ── Disk / LVM ───────────────────────────────────────────────────────────────
test_separate_boot_efi    { contains(ks, "part /boot/efi") }
test_separate_boot        { contains(ks, "part /boot") }
test_lvm_volgroup_rhel    { contains(ks, "volgroup rhel") }
test_var_nodev            { contains(ks, "/var"); contains(ks, "nodev") }
test_tmp_noexec           { contains(ks, "--name=tmp"); contains(ks, "noexec") }
test_tmp_nosuid           { contains(ks, "nosuid") }

# ── Security ─────────────────────────────────────────────────────────────────
test_selinux_enforcing      { contains(ks, "selinux --enforcing") }
test_root_password_locked   { contains(ks, "rootpw --lock") }
test_sssd_authselect        { contains(ks, "authselect select sssd") }

# ── Firewall ─────────────────────────────────────────────────────────────────
test_firewall_enabled       { contains(ks, "firewall --enabled") }
test_microshift_api_port    { contains(ks, "6443:tcp") }
test_mqtt_port              { contains(ks, "1883:tcp") }
test_metrics_port           { contains(ks, "9090:tcp") }

# ── Post-install ─────────────────────────────────────────────────────────────
test_post_section_present           { contains(ks, "%post") }
test_node_metadata_json_written     { contains(ks, "/etc/woolies/node-metadata.json") }
test_greenboot_script_installed     { contains(ks, "40-woolies-store-health.sh") }
test_audit_rules_written            { contains(ks, "/etc/audit/rules.d/99-woolies.rules") }
test_core_dumps_disabled            { contains(ks, "fs.suid_dumpable = 0") }
test_migration_phase_in_metadata    { contains(ks, `"migration_phase": "P1"`) }
test_cis_tmp_fstab_options          { contains(ks, "nodev,noexec,nosuid") }

# ── ZTP / ostree ─────────────────────────────────────────────────────────────
test_ostree_configured      { contains(ks, "ostreesetup") }
test_ostree_edge_ref        { contains(ks, "rhel/9/x86_64/edge") }
test_au_timezone            { contains(ks, "Australia/Sydney") }
test_unattended_reboot      { contains(ks, "reboot") }
test_no_graphical_install   { not contains(ks, "graphical") }