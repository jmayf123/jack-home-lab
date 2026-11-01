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

module "ts_router" {
  source = "./services/ts-router"

  ts_router_ip                = var.ts_router_ip
  ts_router_lxc_root_password = var.ts_router_lxc_root_password
  gw_ip                       = var.gw_ip
}

module "adguard" {
  source = "./services/adguard"

  adguard_ip                = var.adguard_ip
  adguard_lxc_root_password = var.adguard_lxc_root_password
  gw_ip                     = var.gw_ip
}

module "vault" {
  source = "./services/vault"

  vault_ip                = var.vault_ip
  vault_lxc_root_password = var.vault_lxc_root_password
  gw_ip                   = var.gw_ip
}

module "pic" {
  source = "./services/pic"

  pic_ip                = var.pic_ip
  pic_lxc_root_password = var.pic_lxc_root_password
  gw_ip                 = var.gw_ip

  pic_vm_id          = var.pic_vm_id
  pic_vm_ip          = var.pic_vm_ip
  pic_vm_user        = var.pic_vm_user
  pic_ssh_public_key = var.pic_ssh_public_key
  pic_vm_template    = var.pic_vm_template
  pic_vm_storage     = var.pic_vm_storage
  pic_vm_cores       = var.pic_vm_cores
  pic_vm_memory      = var.pic_vm_memory
  pic_vm_disk_gb     = var.pic_vm_disk_gb
  nas_ip             = var.nas_ip
}

output "pic_immich_url" {
  value     = module.pic.pic_immich_url
  sensitive = true
}

# dash - service informatrion dashboard

# llm - Ollama with Open Web UI for local llm
