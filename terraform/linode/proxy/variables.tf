variable "linode_token" {
  type        = string
  description = "Linode API Token used in provider.tf"
}

variable "authorized_keys" {
  type        = list(string)
  description = "Authorized SSH Keys"
  default     = [""]
}

variable "image" {
  type    = string
  default = "linode/alpine3.24"
}

variable "region" {
  type        = string
  description = "Linode region (us-iad = Washington DC / Ashburn)"
  default     = "us-iad"
}

variable "ssh_user" {
  type    = string
  default = "aearles"
}

variable "ssh_port" {
  type    = number
  default = 443
}

variable "ssh_allowed_ipv4" {
  type        = list(string)
  description = "IPv4 CIDRs allowed to reach SSH. Restrict to your public IP if it is stable."
  default     = ["0.0.0.0/0"]
}

variable "fqdn" {
  type    = string
  default = "proxy.local"
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "tags" {
  type        = list(string)
  description = "List of tags to apply"
  default     = []
}

# variable "root_pass" { //Replaced with random_password.root_pass
#   type        = string
#   description = "Password for root account"
# }