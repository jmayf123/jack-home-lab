#Set your public SSH key here
variable "ssh_key" {
  default = "your_public_ssh_key_here"
}
#Provide the url of the host you would like the API to communicate on.
#It is safe to default to setting this as the URL for what you used
#as your `proxmox_host`, although they can be different
variable "pm_api_url" {
    default = "https://<proxmox-host-ip>:8006/api2/json"
}
#Blank var for use by secrets.tfvars
variable "pm_api_token_id" {
}
variable "pm_api_token_secret" {
}
variable "ts_router_lxc_root_password" { 
}
variable "adguard_lxc_root_password" {
}