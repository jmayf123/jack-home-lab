terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

# llm - Ollama + Open WebUI, GPU-accelerated via the host's RX 6700 XT
#
# GPU access (/dev/dri/renderD128 and /dev/kfd) is NOT configured here: the
# Telmate provider has no device-passthrough attribute and our API token isn't
# root@pam, so Proxmox would reject it anyway. Apply lxc.conf.snippet on the
# host after the container exists (see docs/llm-notes.md).
resource "proxmox_lxc" "llm" {
  target_node  = "pve"
  hostname     = "llm"
  vmid         = 105
  ostemplate   = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  unprivileged = true
  password     = var.llm_lxc_root_password

  # Start small; models run fully in VRAM, so system RAM mostly serves Open WebUI.
  # cores/memory aren't in ignore_changes, so editing them + `terraform apply`
  # resizes the container in place.
  cores    = 4
  cpulimit = 0
  memory   = 8192
  swap     = 512

  # Models live here (~5G per 8B model). Grow with `pct resize 105 rootfs +NG`
  # on the host, then update this value to match.
  rootfs {
    storage = "local"
    size    = "40G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = var.llm_ip
    gw     = var.gw_ip
  }

  lifecycle {
    ignore_changes = [
      description,
      onboot,
      password,
      tags,
      ostemplate,
      features,
      rootfs,
      network,
      cpulimit,
      cmode,
      start,
      target_node,
    ]
  }
}
