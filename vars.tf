variable "pm_api_url" {
  type      = string
  sensitive = true
}
variable "pm_api_token_id" {
  type      = string
  sensitive = true
}
variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}
variable "gw_ip" {
  type      = string
  sensitive = true
}

########## SERVICE-SPECIFIC (passed through to modules) ##########

variable "ts_router_ip" {
  type      = string
  sensitive = true
}
variable "ts_router_lxc_root_password" {
  type      = string
  sensitive = true
}
variable "adguard_ip" {
  type      = string
  sensitive = true
}
variable "adguard_lxc_root_password" {
  type      = string
  sensitive = true
}
variable "vault_ip" {
  type      = string
  sensitive = true
}
variable "vault_lxc_root_password" {
  type      = string
  sensitive = true
}
variable "pic_ip" {
  type      = string
  sensitive = true
}
variable "pic_lxc_root_password" {
  type      = string
  sensitive = true
}

variable "pic_vm_id" {
  type    = number
  default = 105
}
variable "pic_vm_ip" {
  type      = string
  sensitive = true
}
variable "pic_vm_user" {
  type    = string
  default = "jack"
}
variable "pic_ssh_public_key" {
  type = string
}
variable "pic_vm_template" {
  type    = string
  default = "debian-12-cloudinit"
}
variable "pic_vm_storage" {
  type    = string
  default = "local-lvm"
}
variable "pic_vm_cores" {
  type    = number
  default = 4
}
variable "pic_vm_memory" {
  type    = number
  default = 8192
}
variable "pic_vm_disk_gb" {
  type    = number
  default = 40
}
variable "nas_ip" {
  type      = string
  sensitive = true
}
