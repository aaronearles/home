locals {
  tags = {
    hello = "world"
  }
}

############### IMPORT EXISTING RESOURCE DEPENDENCIES ##############

# data "azurerm_client_config" "current" {} //Pulls in current deployment user tenant and object ID's.

# data "azurerm_resource_group" "vnet-rg" {
#   name = var.vnet-rg
# }

# output "vnet-rg-id" {
#   value = data.azurerm_resource_group.vnet-rg.id
# }

# data "azurerm_virtual_network" "vnet" {
#   name                = var.vnet
#   resource_group_name = data.azurerm_resource_group.vnet-rg.name
# }

# output "vnet-id" {
#   value = data.azurerm_virtual_network.vnet.id
# }

# data "azurerm_subnet" "workload-snet" {
#   name                 = var.workload-snet
#   virtual_network_name = var.vnet
#   resource_group_name  = data.azurerm_resource_group.vnet-rg.name
# }

# output "workload-snet-id" {
#   value = data.azurerm_subnet.workload-snet.id
# }

data "http" "myip" { //Retrieves current public IP address of system running terraform to use in NSG using "${chomp(data.http.myip.body)}/32"
  url = "http://ipv4.icanhazip.com"
}

########## RG CONFIGURATION #########

resource "azurerm_resource_group" "rg" {
  name     = var.rg
  location = var.location

  tags = local.tags
}

########## ASG CONFIGURATION #########

resource "azurerm_application_security_group" "winvm-asg" {
  name                = "${var.prefix}${var.service_name}${var.env}-ASG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.tags

}

resource "azurerm_network_interface_application_security_group_association" "winvm-nic-asg-association" {
  for_each                      = { for i in var.vm_list : "key_${i}" => i }
  network_interface_id          = azurerm_network_interface.winvm-nic[each.key].id
  application_security_group_id = azurerm_application_security_group.winvm-asg.id
}


########## NSG CONFIGURATION #########

resource "azurerm_network_security_group" "winvm-nsg" {
  name                = "${var.prefix}${var.service_name}${var.env}-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.tags

  security_rule {
    name                       = "AZURE-GATEWAYMANAGER-IN" //Required rule to support AppGw attachment (if applicable)
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "MYIP-IN" //Allow access from the public IP (likely GlobalProtect) of the system running terraform (retrieved in data.http.myip above).
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "${chomp(data.http.myip.response_body)}/32"
    destination_address_prefix = "*"
    # destination_application_security_group_ids = [azurerm_application_security_group.winvm-asg.id]
  }

}

########## VNET CONFIGURATION #########

## USED IF NOT IMPORTING EXISTING, CURRENTLY REQUIRES COMMENTING UNUSED VARIABLES ETC

resource "azurerm_virtual_network" "winvm-vnet" {
  name                = "${var.prefix}${var.service_name}${var.env}-VNET"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.223.0.0/16"]
  dns_servers         = ["168.63.129.16"]

  tags = local.tags
}

resource "azurerm_subnet" "winvm-gatewaysubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.winvm-vnet.name
  address_prefixes     = ["10.223.254.0/24"]

}

resource "azurerm_subnet" "winvm-subnet01" {
  name                 = "subnet01"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.winvm-vnet.name
  address_prefixes     = ["10.223.100.0/24"]

}

resource "azurerm_subnet_network_security_group_association" "winvm-subnet01-nsg-association" {
  subnet_id                 = azurerm_subnet.winvm-subnet01.id
  network_security_group_id = azurerm_network_security_group.winvm-nsg.id
}

resource "azurerm_subnet" "winvm-subnet02" {
  name                 = "subnet02"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.winvm-vnet.name
  address_prefixes     = ["10.223.200.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "winvm-subnet02-nsg-association" {
  subnet_id                 = azurerm_subnet.winvm-subnet02.id
  network_security_group_id = azurerm_network_security_group.winvm-nsg.id
}

########## UDR CONFIGURATION #########

# TBD

########## VM CONFIGURATION ##########

resource "azurerm_public_ip" "winvm-pip" {
  for_each            = { for i in var.vm_list : "key_${i}" => i }
  name                = "${var.prefix}${var.service_name}${format("%02d", each.value)}${var.env}-pip"
  sku                 = "Standard"
  sku_tier            = "Regional"
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "winvm-nic" {
  //name       = "${var.vm_name}-nic"
  for_each                      = { for i in var.vm_list : "key_${i}" => i }
  name                          = "${var.prefix}${var.service_name}${format("%02d", each.value)}${var.env}-nic"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  enable_accelerated_networking = var.vm_enable_accelerated_networking
  tags                          = local.tags

  ip_configuration {
    name = "internal"
    # subnet_id                     = data.azurerm_subnet.workload-snet.id //used when importing existing vnet
    subnet_id                     = azurerm_subnet.winvm-subnet01.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.winvm-pip[each.key].id
  }
}

resource "azurerm_windows_virtual_machine" "winvm" {
  //name                = var.vm_name
  for_each            = { for i in var.vm_list : "key_${i}" => i }
  name                = "${var.prefix}${var.service_name}${format("%02d", each.value)}${var.env}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  //network_interface_ids = [ azurerm_network_interface.winvm-nic.id ]
  network_interface_ids = [azurerm_network_interface.winvm-nic[each.key].id]

  tags = local.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_os.publisher
    offer     = var.vm_os.offer
    sku       = var.vm_os.sku
    version   = var.vm_os.version
  }
}

# resource "azurerm_managed_disk" "winvm-datadisk" {
#   for_each = { for i in var.vm_list : "key_${i}" => i }
#   name     = "${var.prefix}${var.service_name}${format("%02d", each.value)}${var.env}-datadisk"
#   //name                 = "${var.vm_name}-datadisk"
#   location             = azurerm_resource_group.rg.location
#   resource_group_name  = azurerm_resource_group.rg.name
#   storage_account_type = "Standard_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = "500"

# tags = local.tags
# }

# resource "azurerm_virtual_machine_data_disk_attachment" "winvm-datadisk-attachment" {
#   for_each = { for i in var.vm_list : "key_${i}" => i }
#   //managed_disk_id    = azurerm_managed_disk.winvm-datadisk.id
#   managed_disk_id    = azurerm_managed_disk.winvm-datadisk[each.key].id
#   virtual_machine_id = azurerm_windows_virtual_machine.winvm[each.key].id
#   lun                = "10"
#   caching            = "ReadWrite"
# }

############### VM SCRIPT EXTENSION ###############

## WinRM QuickConfig ## //TESTING

resource "azurerm_virtual_machine_extension" "winvm_script" {
  for_each                   = { for i in var.vm_list : "key_${i}" => i }
  name                       = "${var.prefix}${var.service_name}${format("%02d", each.value)}${var.env}_winrm"
  virtual_machine_id         = azurerm_windows_virtual_machine.winvm[each.key].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true
  # settings = var.vm_script
  settings = <<SETTINGS
    {
      "fileUris": ["https://gist.githubusercontent.com/aaronearles/2964d6e034fc2589ba4a70ca56256225/raw/417ecb41fca35eb2972a9548a8efc72dbf032255/enable_winrm.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File enable_winrm.ps1"
    }
  SETTINGS


  tags = local.tags

}

############### SUPPORTING INFRASTRUCTURE ###############

## TODO: CONDITIONAL DEPLOYMENT OF ILB, AGW, AZSQL, SQLMI, ETC.