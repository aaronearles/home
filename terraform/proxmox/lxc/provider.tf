variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}

# variable "pm_user" {
#   type = string
# }

# variable "pm_password" {
#   type = string
# }

terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "~>3.0.1-rc3"
    }
  }

  backend "local" {
    path = "/mnt/nfs/code/terraform_state/proxmox_400.tfstate"
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  # pm_user = var.pm_user
  # pm_password = var.pm_password
}
