terraform {
  required_version = ">= 1.0"
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.41"
    }
  }
}

provider "unifi" {
  # username       = var.unifi_username
  # password       = var.unifi_password
  api_key        = var.unifi_api_key
  api_url        = var.unifi_api_url
  allow_insecure = var.unifi_allow_insecure
}