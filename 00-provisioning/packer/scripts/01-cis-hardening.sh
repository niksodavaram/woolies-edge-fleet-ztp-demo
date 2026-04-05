#!/usr/bin/env bash
# CIS RHEL 9 Level 2 Hardening — applied at Packer build time
# Ensures every Golden Image is compliant before fleet deployment
set -euo pipefail

echo "[woolies-cis] Starting CIS Level 2 hardening..."

# 1.1 Filesystem restrictions
for fs in cramfs freevxfs jffs2 hfs hfsplus squashfs udf; do
  echo "install $fs /bin/true" >> /etc/modprobe.d/cis-blacklist.conf
done

# 1.2 Partitioning (assuming kickstart set up /tmp as separate partition)
if mountpoint -q /tmp; then
  mount -o remount,nodev,nosuid,noexec /tmp
fi

# 2.1 Services — disable unnecessary
systemctl disable --now avahi-daemon cups rpcbind bluetooth 2>/dev/null || true

# 3.1 Network hardening
cat >> /etc/sysctl.d/99-cis-network.conf <<EOF
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv6.conf.all.disable_ipv6 = 1
EOF
sysctl --system

# 4.1 Auditd rules (PCI-DSS + CIS)
cat >> /etc/audit/rules.d/99-woolies.rules <<EOF
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege_escalation
-a always,exit -F arch=b64 -S execve -k exec_commands
-a always,exit -F arch=b64 -S open,openat,open_by_handle_at -F exit=-EACCES -k access
EOF

# 5.1 SSH hardening
cat > /etc/ssh/sshd_config.d/99-woolies-cis.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
X11Forwarding no
MaxAuthTries 4
AllowAgentForwarding no
AllowTcpForwarding no
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 3
Banner /etc/issue.net
EOF

echo "[woolies-cis] CIS Level 2 hardening complete."
