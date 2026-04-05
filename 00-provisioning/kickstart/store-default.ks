# store-default.ks — Woolworths store edge node ZTP Kickstart
# Zero-touch: store tech plugs in hardware and walks away
# Everything below runs unattended — no prompts, no manual steps
#
# Triggered by: SD-WAN ZTP → PXE boot → DHCP → this file
# Image served from: http://imageserver.woolies.internal/rhel9-edge-latest.iso

# ── Install source ────────────────────────────────────────────────────────────
url --url="http://imageserver.woolies.internal/rhel9-base"
ostreesetup --nogpg \
  --url="http://imageserver.woolies.internal/ostree/repo" \
  --osname="rhel" \
  --ref="rhel/9/x86_64/edge"

# ── Basic config ─────────────────────────────────────────────────────────────
lang en_AU.UTF-8
keyboard us
timezone Australia/Sydney --utc
text
skipx
reboot

# ── Network (SD-WAN assigns via DHCP) ────────────────────────────────────────
network --bootproto=dhcp --onboot=yes --activate --hostname=store-REPLACE-ID

# ── Disk layout (CIS L2 — separate partitions) ───────────────────────────────
ignoredisk --only-use=sda
clearpart --all --initlabel --drives=sda
bootloader --append="console=ttyS0,115200 selinux=1 enforcing=1 audit=1" --location=mbr --boot-drive=sda

# /boot/efi
part /boot/efi --fstype=efi   --size=200  --fsoptions="umask=0077,shortname=winnt"
# /boot
part /boot     --fstype=xfs   --size=1024 --fsoptions="nodev"
# LVM for remaining disk
part pv.01     --fstype=lvmpv --grow
volgroup rhel pv.01
# / — read-only base (ostree)
logvol /       --vgname=rhel --fstype=xfs --size=10240  --name=root
# /var — MicroShift writes here
logvol /var    --vgname=rhel --fstype=xfs --size=20480  --name=var    --fsoptions="nodev"
# /var/lib/microshift — separate for LVMS
logvol /var/lib/microshift --vgname=rhel --fstype=xfs --size=10240 --name=microshift
# /tmp — noexec for CIS
logvol /tmp    --vgname=rhel --fstype=xfs --size=2048   --name=tmp    --fsoptions="nodev,noexec,nosuid"
# /home
logvol /home   --vgname=rhel --fstype=xfs --size=2048   --name=home   --fsoptions="nodev"

# ── Auth / SSH ────────────────────────────────────────────────────────────────
authselect select sssd
rootpw --lock
# Ansible service account — key injected from Vault at first boot via ESO
user --name=ansible-svc --groups=wheel --password="" --iscrypted

# ── Package selection (minimal — rest comes from Image Builder blueprint) ─────
%packages --excludedocs
@^minimal-environment
-iwl*firmware
-ivtv*
%end

# ── SELinux ───────────────────────────────────────────────────────────────────
selinux --enforcing

# ── Firewall ──────────────────────────────────────────────────────────────────
firewall --enabled --ssh --port=6443:tcp,1883:tcp,9090:tcp

# ── Post-install: write node metadata ────────────────────────────────────────
%post --log=/var/log/woolies-kickstart-post.log
#!/bin/bash
set -euo pipefail

# Write node metadata — read by greenboot, MCP agents, Ansible
mkdir -p /etc/woolies
STORE_ID=$(hostname -s | sed 's/store-//')

cat > /etc/woolies/node-metadata.json <<EOF
{
  "store_id":        "${STORE_ID:-UNKNOWN}",
  "image_version":   "$(rpm-ostree status --json | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["deployments"][0].get("version","unknown"))'  2>/dev/null || echo 'unknown')",
  "installed_at":    "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "migration_phase": "P1",
  "platform":        "rhel9-microshift",
  "regional_hub":    "hub-nsw.woolies.internal",
  "kickstart_ver":   "1.3.0"
}
EOF
chmod 644 /etc/woolies/node-metadata.json

# Install greenboot health check
mkdir -p /etc/greenboot/check/required.d
cp /tmp/greenboot-check.sh /etc/greenboot/check/required.d/40-woolies-store-health.sh
chmod +x /etc/greenboot/check/required.d/40-woolies-store-health.sh

# Set correct fstab options for /tmp (CIS 1.1.3)
sed -i '/\/tmp/s/defaults/defaults,nodev,noexec,nosuid/' /etc/fstab

# Disable core dumps (CIS 1.5.1)
echo '* hard core 0' >> /etc/security/limits.conf
echo 'fs.suid_dumpable = 0' >> /etc/sysctl.d/99-woolies-cis.conf

# Audit rules (CIS 4.1)
cat > /etc/audit/rules.d/99-woolies.rules <<'AUDIT'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k priv_esc
-w /var/log/lastlog -p wa -k logins
-a always,exit -F arch=b64 -S execve -k exec
AUDIT

echo "Woolies Kickstart post-install complete: $(date -u)" >> /var/log/woolies-kickstart-post.log
%end
