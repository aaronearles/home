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

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
    # ansible = {
    #   source  = "ansible/ansible"
    #   version = "~> 1.2.0"
    # }
  }

  backend "local" {
    path = "/mnt/nfs/code/terraform_state/proxmox_k3s_cluster.tfstate"
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  # pm_user = var.pm_user
  # pm_password = var.pm_password
}
