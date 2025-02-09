terraform {
  required_providers {
    linode = {
      source = "linode/linode"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# Configure the Linode Provider
provider "linode" {
  token = var.linode_token
}
