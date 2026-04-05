# ============================================================
# Woolworths Edge Fleet — RHEL 9 Golden Image Builder
# Packer HCL2 — produces ISO + QCOW2 artifacts
# Image metadata driven by image.toml (RHEL Image Builder spec)
# ============================================================

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# ---- Variables -----------------------------------------------------------
variable "rhel_iso_url" {
  type    = string
  default = "https://cdn.redhat.com/content/dist/rhel9/9/x86_64/baseos/iso/RHEL-9.4.0-x86_64-dvd.iso"
}

variable "rhel_iso_checksum" {
  type    = string
  default = "sha256:YOUR_CHECKSUM_HERE"
}

variable "output_directory" {
  type    = string
  default = "output/woolies-rhel9-golden"
}

variable "disk_size" {
  type    = number
  default = 61440 # 60 GB — aligns with Dell DTCP local NVMe
}

variable "memory" {
  type    = number
  default = 4096
}

variable "cpus" {
  type    = number
  default = 4
}

variable "image_version" {
  type    = string
  default = "1.0.0"
}

# ---- Source: QEMU --------------------------------------------------------
source "qemu" "woolies-rhel9" {
  iso_url          = var.rhel_iso_url
  iso_checksum     = var.rhel_iso_checksum
  output_directory = var.output_directory
  disk_size        = var.disk_size
  memory           = var.memory
  cpus             = var.cpus
  format           = "qcow2"
  accelerator      = "kvm"
  headless         = true

  # Boot via Kickstart for fully unattended ZTP
  boot_command = [
    "<up><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/store-default.ks",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]

  http_directory = "../kickstart"

  ssh_username     = "ansible"
  ssh_password     = "REPLACE_WITH_VAULT_SECRET"
  ssh_timeout      = "30m"
  shutdown_command = "sudo systemctl poweroff"

  vm_name = "woolies-rhel9-edge-v${var.image_version}"
}

# ---- Build ---------------------------------------------------------------
build {
  name    = "woolies-rhel9-golden"
  sources = ["source.qemu.woolies-rhel9"]

  # Step 1: Apply CIS Level 2 hardening
  provisioner "shell" {
    scripts = [
      "scripts/01-cis-hardening.sh",
      "scripts/02-disable-unused-services.sh",
      "scripts/03-configure-auditd.sh",
      "scripts/04-install-agents.sh"
    ]
  }

  # Step 2: Inject image metadata from image.toml
  provisioner "file" {
    source      = "../image-metadata/image.toml"
    destination = "/etc/woolies/image.toml"
  }

  # Step 3: Stamp build provenance
  provisioner "shell" {
    inline = [
      "echo 'WOOLIES_IMAGE_VERSION=${var.image_version}' >> /etc/os-release",
      "echo 'WOOLIES_BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)' >> /etc/os-release",
      "echo 'WOOLIES_BUILD_PIPELINE=packer-gitlab-ci' >> /etc/os-release",
      "systemctl enable --now auditd",
      "systemctl enable --now chronyd"
    ]
  }

  # Step 4: Sysprep / cleanup
  provisioner "shell" {
    scripts = ["scripts/99-sysprep.sh"]
  }

  # Step 5: Generate SBOM + manifest
  post-processor "manifest" {
    output     = "output/build-manifest.json"
    strip_path = true
  }
}
