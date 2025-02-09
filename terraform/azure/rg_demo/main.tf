terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      #   version = "3.53.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "stateful-rg"
    storage_account_name = "aearles00"
    container_name       = "terraform"
    # use_azuread_auth     = true
    key = "rg_demo"
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

locals {
  tags = {
    hello = "world"
  }
}

resource "azurerm_resource_group" "rg_demo-rg" {
  for_each = { for i in var.rg_list : "key_${i}" => i }
  # name     = "rg_demo-rg"
  name     = "${var.prefix}${var.service_name}${format("%02d", each.value)}${var.env}-rg"
  location = var.location
  tags     = local.tags
}
