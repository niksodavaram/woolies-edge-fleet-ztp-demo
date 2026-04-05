# kcli-based ZTP Lab (Hub + Spokes)

This describes how to spin up a **virtual ZTP lab** using kcli: one hub cluster +
one or more spoke SNO clusters to test SiteConfig + PolicyGenerator flows. [web:158][web:177][web:178][web:181][web:179]

## 1. Install kcli and prerequisites

On a RHEL 9 / Fedora host with virtualization:

```bash
sudo dnf -y install libvirt libvirt-daemon-driver-qemu qemu-kvm
sudo systemctl enable --now libvirtd

sudo dnf -y copr enable karmab/kcli
sudo dnf -y install kcli

# Add your user to libvirt group
sudo usermod -aG libvirt $(id -un)
newgrp libvirt
```

## 2. Download OpenShift clients

```bash
for cmd in oc openshift-install; do
  kcli download ${cmd}
  sudo mv ${cmd} /usr/local/bin/
done
```

## 3. Define kcli plan for hub + spokes

Create `kcli-plan-hub-spokes.yml` (example):

```yaml
parameters:
  hub_memory: 16384
  hub_cpus: 4
  spoke_count: 1
  spoke_memory: 16384
  spoke_cpus: 4
  network: default

vms:
  hub:
    memory: "{{ hub_memory }}"
    numcpus: "{{ hub_cpus }}"
    nets:
      - name: "{{ network }}"
    disks:
      - size: 120
  {% for i in range(1, spoke_count + 1) %}
  spoke{{ i }}:
    memory: "{{ spoke_memory }}"
    numcpus: "{{ spoke_cpus }}"
    nets:
      - name: "{{ network }}"
    disks:
      - size: 120
  {% endfor %}
```

Apply the plan:

```bash
kcli create plan -f kcli-plan-hub-spokes.yml ztp-lab
```

This creates VMs for a hub and one spoke, similar to RH’s ZTP demos. [web:158][web:177][web:178]

## 4. Install hub cluster on the hub VM

SSH into `hub`, use `openshift-install` (IPI or UPI as preferred), and then:

```bash
export KUBECONFIG=/root/.kcli/clusters/hub/auth/kubeconfig

# Install RHACM + OpenShift GitOps (not detailed here)
# oc apply -f rhacm-subscription.yaml
# oc apply -f openshift-gitops-subscription.yaml
```

## 5. Register spoke SNO via GitOps ZTP

On the hub:

1. **Create Git webhook/secret** so RHACM/openshift-gitops can read this repo.
2. Apply the ZTP resources from this repo:

```bash
# On hub cluster
export KUBECONFIG=/root/.kcli/clusters/hub/auth/kubeconfig

# SiteConfig + PolicyGenerator from this repo
oc apply -f 02-infrastructure/ztp/siteconfig-store-001.yaml
oc apply -f 02-infrastructure/ztp/policygenerator-common.yaml
```

3. RHACM/PolicyGenerator generates `Policy` objects that create the spoke cluster
   against the `spoke1` VM, using the BMC/IPMI emulation (e.g. sushy-tools) if configured. [web:171][web:172][web:175][web:184]

## 6. Test ZTP flow end-to-end

Once the spoke SNO is up:

- RHACM reports cluster `store-001-bondi` as `Ready`.
- ArgoCD (OpenShift GitOps) uses `app-of-apps.yaml` from this repo to:
  - Bootstrap infra (MachineConfig, monitoring).
  - Deploy workloads (scan-assist-ai, MQTT/DDS, KubeVirt Windows, etc.).
- You can simulate failures and observe MCP agents’ decisions at the hub.

> This kcli lab is **not** production; it’s a reproducible environment to validate
> the ZTP GitOps flows defined in `02-infrastructure/ztp/` and `04-secrets-cicd/argo-cd/`.