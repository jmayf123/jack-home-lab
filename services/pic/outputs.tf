output "pic_vm_ip" {
  value     = split("/", var.pic_vm_ip)[0]
  sensitive = true
}

output "pic_immich_url" {
  value     = "http://${split("/", var.pic_vm_ip)[0]}:2283"
  sensitive = true
}

output "pic_setup_command" {
  description = "Run after terraform apply to configure the VM (setup.sh prompts for SMB credentials)."
  value       = "scp scripts/setup.sh ${var.pic_vm_user}@${split("/", var.pic_vm_ip)[0]}: && ssh -t ${var.pic_vm_user}@${split("/", var.pic_vm_ip)[0]} 'sudo NAS_IP=${var.nas_ip} bash setup.sh'"
  sensitive   = true
}
