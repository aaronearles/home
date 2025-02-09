variable "VULTR_API_KEY" {
  type        = string
  description = "https://my.vultr.com/settings/#settingsapi"
}

variable "plan" {
  type        = string
  description = ""
  default     = "vc2-1c-1gb" //"vc2-1c-1gb","vc2-1c-2gb","vc2-2c-2gb","vc2-2c-4gb" //"vhp-1c-1gb-amd","vhp-1c-2gb-amd","vhp-2c-2gb-amd","vhp-2c-4gb-amd","vhp-4c-8gb-amd" //"voc-c-1c-2gb-25s-amd","voc-c-2c-4gb-50s-amd","voc-c-2c-4gb-75s-amd","voc-c-4c-8gb-75s-amd","voc-c-4c-8gb-150s-amd"
}

variable "region" {
  type        = string
  description = ""
  default     = "lax" //Los Angeles / ewr = New Jersey / atl, dfw, mia, ord, sea, sjc
}

variable "os_id" {
  type        = string
  description = "Vultr OS ID#"
  default = "1743" //Ubuntu 22.04 LTS, or "2136" //Debian 12, or "1869" //Rocky 9
}

variable "label" {
  type        = string
  description = ""
}

variable "hostname" {
  type        = string
  description = ""
}

variable "tags" {
  type        = list(string)
  description = "value"
  default     = ["no-tags"]
}

variable "ddos_protection" {
  type    = string
  default = "false"
}

variable "activation_email" {
  type    = string
  default = "true"
}

variable "ssh_key_ids" {
  type        = list(string)
  description = "List of accepted SSH Keys in Vultr UUID format -- https://my.vultr.com/settings/#settingssshkeys or https://www.vultr.com/api/#tag/ssh/operation/get-ssh-key"
}