#ESTABLISH VARIABLES FOR USE IN TERRAFORM BUT DO NOT DEFINE VALUES HERE, USE VARIABLES/SECRETS IN GITHUB ACTIONS
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}

###################### ENVIRONMENT PREREQS ######################

variable "location" {
  type        = string
  description = "Azure region for deployment"
  # default     = "East US"
}

variable "rg" {
  type        = string
  description = "New Resource Group to be created"
}

variable "vnet-rg" {
  type        = string
  description = "Existing VNET RG name in Azure"
}

variable "vnet" {
  type        = string
  description = "Existing VNET name in Azure"
}

variable "workload-snet" {
  type        = string
  description = "Existing WL Subnet name in Azure"
}

################# SUPPORTING INFRA #################

variable "infra_ilb_req" {
  type        = bool
  description = "Is an Internal Load Balancer required? True or False"
  default     = false
}

variable "infra_agw_req" {
  type        = bool
  description = "Is an Application Gateway required? True or False"
  default     = false
}

variable "infra_azsql_req" {
  type        = bool
  description = "Is an Azure SQL Server required? True or False"
  default     = false
}

variable "infra_sqlmi_req" {
  type        = bool
  description = "Is a SQL Managed Instance required? True or False"
  default     = false
}



################# NAMING CONVENTION #################

variable "prefix" {
  type    = string
  default = "AZ"
}
variable "service_name" {
  type        = string
  description = "Name of service (OUTSYSAPP) -- Define in terraform.tfvars"
}
variable "vm_list" {
  type        = list(any)
  description = "List of server numbers ([01,02,03]) -- Define in terraform.tfvars"
}
variable "env" {
  type        = string
  description = "Environment abreviation -- Define in terraform.tfvars"
}


###################### VM SPECS ######################

variable "vm_size" {
  type        = string
  description = "Size of VM(s) to deploy"
}

variable "vm_enable_accelerated_networking" {
  type        = bool
  description = "Toggle accelerated networking, depending on whether it's supported by selected VM size."
}

# variable "vm_name" {
#   type = string
#   default = ""
# }

variable "vm_os" {
  description = "OS image to deploy"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

################# CREDENTIALS #################

variable "vm_username" {
  type        = string
  description = "Windows Admin Username -- Define in terraform.tfvars"
}
variable "vm_password" {
  type        = string
  description = "Windows Admin Password -- Define in terraform.tfvars"
}
