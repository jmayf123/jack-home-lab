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
