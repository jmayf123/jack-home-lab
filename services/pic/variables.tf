variable "pic_ip" {
  type      = string
  sensitive = true
}
variable "pic_lxc_root_password" {
  type      = string
  sensitive = true
}
variable "gw_ip" {
  type      = string
  sensitive = true
}

########## VM (Immich) ##########

variable "pic_vm_id" {
  type        = number
  description = "VMID for the Immich VM. Container 104 is the old LXC; VMs and CTs share the ID space."
  default     = 105
}
variable "pic_vm_ip" {
  type        = string
  sensitive   = true
  description = "Static IP in CIDR form, e.g. 192.168.1.50/24 (or \"dhcp\")."
}
variable "pic_vm_user" {
  type    = string
  default = "jack"
}
variable "pic_ssh_public_key" {
  type        = string
  description = "SSH public key injected via cloud-init."
}
variable "pic_vm_template" {
  type        = string
  description = "Name of the Debian 12 cloud-init template to clone (see scripts/create-template.sh)."
  default     = "debian-12-cloudinit"
}
variable "pic_vm_storage" {
  type        = string
  description = "Storage for the VM disk and cloud-init drive."
  default     = "local-lvm"
}
variable "pic_vm_cores" {
  type    = number
  default = 4
}
variable "pic_vm_memory" {
  type        = number
  description = "MB"
  default     = 8192
}
variable "pic_vm_disk_gb" {
  type    = number
  default = 40
}
variable "nas_ip" {
  type        = string
  sensitive   = true
  description = "NAS IP. Not used by the VM resource; only echoed in the setup_command output."
}
