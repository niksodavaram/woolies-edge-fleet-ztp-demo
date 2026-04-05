# ============================================================
# Woolworths Edge Fleet — RHEL 9 Kickstart (ZTP Answer File)
# Zero Touch Provisioning for Dell DTCP hardware
# Referenced by Packer AND PXE/UEFI boot for bare-metal install
# ============================================================

# Installation method
cdrom
text

# Language and timezone
lang en_AU.UTF-8
timezone Australia/Sydney --utc
keyboard us

# Network (uses DHCP initially; Ansible locks to static post-boot)
network --bootproto=dhcp --device=link --activate
hostname store-edge-node.woolies.internal

# Root account — disabled post-bootstrap via Ansible
rootpw --lock

# Ansible service account (key-only after first boot)
user --name=ansible --groups=wheel --password=REPLACE_PACKER_TEMP_PASS
sshkey --username=ansible "ssh-ed25519 REPLACE_WITH_ANSIBLE_PUBKEY woolies-fleet-deploy"

# Security: SELinux enforcing
selinux --enforcing
firewall --enabled --service=ssh

# Bootloader
bootloader --location=mbr --boot-drive=sda --append="quiet audit=1 intel_iommu=on"

# Disk partitioning — CIS-compliant separate partitions
clearpart --all --initlabel --drives=sda
part /boot       --fstype=xfs  --size=1024  --ondrive=sda
part /boot/efi   --fstype=efi  --size=512   --ondrive=sda
part pv.01       --grow        --size=1     --ondrive=sda

volgroup vg_root pv.01
logvol /              --vgname=vg_root --fstype=xfs  --size=20480 --name=lv_root
logvol /tmp           --vgname=vg_root --fstype=xfs  --size=4096  --name=lv_tmp   --fsoptions="nodev,nosuid,noexec"
logvol /var           --vgname=vg_root --fstype=xfs  --size=10240 --name=lv_var
logvol /var/log       --vgname=vg_root --fstype=xfs  --size=4096  --name=lv_varlog
logvol /var/log/audit --vgname=vg_root --fstype=xfs  --size=2048  --name=lv_audit
logvol /home          --vgname=vg_root --fstype=xfs  --size=4096  --name=lv_home  --fsoptions="nodev"
logvol swap           --vgname=vg_root --fstype=swap --size=4096  --name=lv_swap

# Package selection
%packages --ignoremissing
@^minimal-environment
@standard
kickstart-helper
podman
skopeo
openshift-clients
nmstate
chrome-remote-desktop
chrony
rsyslog
audit
aide
firewalld
bind-utils
net-tools
-postfix
-sendmail
-telnet
%end

# Post-install: register with Red Hat, pull bootstrap token from Vault
%post --log=/var/log/kickstart-post.log
echo "[woolies-ks] Post-install bootstrap starting..."

# Register with RHSM (satellite or RHN)
subscription-manager register \
  --org=WOOLIES_ORG_ID \
  --activationkey=woolies-edge-fleet \
  --auto-attach 2>/dev/null || true

# Enable EPEL for additional tooling
dnf config-manager --set-enabled rhel-9-for-x86_64-appstream-rpms

# Stamp image metadata
mkdir -p /etc/woolies
cat > /etc/woolies/node-metadata.json <<EOF
{
  "provisioned_by": "kickstart-ztp",
  "provisioned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "image_version": "1.0.0",
  "migration_phase": "P1",
  "platform": "dell-dtcp"
}
EOF

# First-boot Ansible trigger
systemctl enable woolies-bootstrap.service 2>/dev/null || true

echo "[woolies-ks] Post-install complete. Node will reboot and auto-bootstrap."
%end

# Reboot after install
reboot --eject
