terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

########## SERVICES ##########  

# ts-router - Tailscale Subnet Router
resource "proxmox_lxc" "ts-router" {
  target_node  = "pve"      # your Proxmox node name
  hostname     = "ts-router"
  vmid         = 100
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
    ip     =  var.ts_router_ip  
    gw     = var.gw_ip       
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
  vmid         = 101
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
    ip     = var.adguard_ip 
    gw     = var.gw_ip
  }

  features {
    keyctl = true
  }
}
# vault - Vaultwarden password manager

# dash - service informatrion dashboard

# llm - Ollama with Open Web UI for local llm

# pic - Immich cloud photos
