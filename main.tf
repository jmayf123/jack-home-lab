terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url         # e.g. https://192.168.1.5:8006/api2/json
  pm_user         = var.pm_user            # e.g. terraform@pve
  pm_password     = var.pm_password
  pm_tls_insecure = true                   # only if using a self-signed cert
}

########## SERVICES ##########  

# ts-router - Tailscale Subnet Router
resource "proxmox_lxc" "ts-router" {
  target_node  = "pve"      # your Proxmox node name
  hostname     = "ts-router"
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst" 
  unprivileged = true
  password     = var.ts_router_lxc_root_password

  cores  = 1
  memory = 512
  swap   = 512

  rootfs {
    storage = "local"   
    size    = "4G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.1.10/24"   
    gw     = "192.168.1.1"       
  }

  # TUN/TAP support — this maps to the "Enable TUN/TAP" checkbox
  features {
    nesting = true
    mount   = ""
  } 
}

# adguard - AdGaurd Network adblocker
resource "proxmox_lxc" "adguard" {
  target_node  = "pve"
  hostname     = "adguard"
  ostemplate   = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  unprivileged = true
  password     = var.adguard_lxc_root_password

  cores  = 1
  memory = 512
  swap   = 512

  rootfs {
    storage = "local"
    size    = "2G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.1.11/24"  
    gw     = "192.168.1.1"
  }

  keyctl = true
}
# vault - Vaultwarden password manager

# dash - service informatrion dashboard

# llm - Ollama with Open Web UI for local llm

# pic - Immich cloud photos
