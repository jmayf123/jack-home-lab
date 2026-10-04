terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

# vault - Vaultwarden password manager
resource "proxmox_lxc" "vault" {
  target_node  = "pve"
  hostname     = "vault"
  vmid         = 102
  ostemplate   = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  unprivileged = true
  password     = var.vault_lxc_root_password

  cores    = 1
  cpulimit = 0
  memory   = 512
  swap     = 512

  rootfs {
    storage = "local"
    size    = "4G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = var.vault_ip
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
