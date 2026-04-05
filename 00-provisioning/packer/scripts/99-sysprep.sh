#!/usr/bin/env bash
# Sysprep — clean up before Golden Image capture
# Removes machine-specific state so every store gets a clean clone
set -euo pipefail

echo "[woolies-sysprep] Cleaning up for image capture..."

# Remove SSH host keys (regenerated on first boot)
rm -f /etc/ssh/ssh_host_*

# Clear machine-id (systemd will generate on first boot)
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Clean package caches
dnf clean all
rm -rf /var/cache/dnf

# Remove temporary files and logs
rm -rf /tmp/* /var/tmp/*
journalctl --rotate --vacuum-time=1s 2>/dev/null || true

# Remove Ansible build credentials (runtime creds injected by Vault)
rm -f /root/.ssh/authorized_keys
sed -i '/ansible/d' /etc/sudoers.d/ansible 2>/dev/null || true

# Zero out free space (reduces QCOW2 size)
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null; rm -f /EMPTY

echo "[woolies-sysprep] Sysprep complete. Image ready for capture."
