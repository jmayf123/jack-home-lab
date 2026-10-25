terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

# pic - Immich self-hosted photo/video backup
resource "proxmox_lxc" "pic" {
  target_node  = "pve"
  hostname     = "pic"
  vmid         = 104
  ostemplate   = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  unprivileged = true
  password     = var.pic_lxc_root_password

  cores    = 2
  cpulimit = 0
  memory   = 4096
  swap     = 512

  # Required for Docker (server, Postgres, Redis, ML service) to run inside
  # an unprivileged LXC.
  features {
    nesting = true
    keyctl  = true
  }

  rootfs {
    storage = "local"
    size    = "20G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = var.pic_ip
    gw     = var.gw_ip
  }

  lifecycle {
    ignore_changes = [
      description,
      onboot,
      password,
      tags,
      ostemplate,
      rootfs,
      network,
      cpulimit,
      cmode,
      start,
      target_node,
    ]
  }
}
