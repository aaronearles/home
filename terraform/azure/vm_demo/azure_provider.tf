terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # version = "3.53.0"
    }
    random = {
      source = "hashicorp/random"
    }
    http = {
      source = "hashicorp/http"
    }
  }

  backend "azurerm" {
    resource_group_name  = "stateful-rg"
    storage_account_name = "aearles00"
    container_name       = "terraform"
    key                  = "vm_demo.tfstate"
  }
}
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
  