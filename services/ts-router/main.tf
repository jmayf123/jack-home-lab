terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

# ts-router - Tailscale Subnet Router
resource "proxmox_lxc" "ts-router" {
  target_node  = "pve" # your Proxmox node name
  hostname     = "ts-router"
  vmid         = 100
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  unprivileged = true
  password     = var.ts_router_lxc_root_password

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
    ip     = var.ts_router_ip
    gw     = var.gw_ip
  }

  # TUN/TAP support — this maps to the "Enable TUN/TAP" checkbox
  features {
    nesting = true
    mount   = ""
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
