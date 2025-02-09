# TESTING ONLY -- TFVARS SHOULD NOT BE USED IN PRODUCTION, USE VARIABLES/SECRETS IN GITHUBACTIONS INSTEAD
# *.TFVARS SHOULD BE IGNORED IN .GITIGNORE

###################### ENVIRONMENT PREREQS ######################
subscription_id = "12345678-abcd-1234-edgh-210987654321" //Replace with valid Subscription ID
tenant_id       = "87654321-dcba-4321-wxyz-112233445566" //Replace with valid Tenant ID
location        = "eastus2"                              //example azure region
rg              = "gha-demo-rg"                          //example resource group

## IF IMPORTING EXISTING VNET ##
vnet-rg       = "demo-net-rg"            #NAME OF EXISTING RG THAT CONTAINS EXISTING VNET
vnet          = "demo-vnet"              #NAME OF EXISTING VNET WHERE NEW VM(s) WILL BE CONNECTED
workload-snet = "LAB-DEMO-WL-10.223.0.0" #NAME OF EXISTING SUBNET WHERE NEW VM(s) WILL BE CONNECTED

################# NAMING CONVENTION #################

# NOTE: MAX 15 CHARACTERS #

prefix       = "AZ"
service_name = "WINVM"
vm_list      = [01, 02]
env          = "LAB"

###################### VM SPECS ######################

vm_size = "Standard_b1s" #Get-AzVMSize -Location $location | Where-Object NumberofCores -Like "4" | Where-Object MemoryinMb -Like 8192

vm_enable_accelerated_networking = false

vm_os = {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2019-Datacenter" # 2016-Datacenter, 2019-Datacenter, 2022-datacenter-azure-edition, 2022-datacenter-azure-edition-hotpatch
  version   = "latest"
}

################# CREDENTIALS #################

# vm_username = ""
# vm_password = ""
