variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}

variable "location" {
  type        = string
  description = "Azure region for deployment"
  default     = "East US"
}

################# NAMING CONVENTION #################

variable "prefix" {
  type    = string
  default = "AZ"
}

variable "service_name" {
  type        = string
  description = "Name of service (APP) -- Define in terraform.tfvars"
}

variable "rg_list" {
  type        = list(any)
  description = "List of server numbers ([01,02,03]) -- Define in terraform.tfvars"
}

variable "env" {
  type        = string
  description = "Environment abreviation -- Define in terraform.tfvars"
}

variable "resource_group_name" {
  type        = string
  description = "Name of new Azure Resource Group"
}
