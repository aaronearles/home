# Example Unifi resources - uncomment and modify as needed
# Reference: https://registry.terraform.io/providers/ubiquiti-community/unifi/latest/docs

data "unifi_network" "default_network" {
  name = "Default"
}

# Example: Create a new WLAN/WiFi network
# resource "unifi_wlan" "example" {
#   name          = "Example-WiFi"
#   passphrase    = "your-wifi-password"
#   security      = "wpapsk"
#   wlan_band     = "both"
#   user_group_id = data.unifi_user_group.default.id
#   site          = var.site
# }

# Example: Create a new network/VLAN
# resource "unifi_network" "example" {
#   name    = "Example-VLAN"
#   purpose = "vlan-only"
#   subnet  = "192.168.100.1/24"
#   vlan_id = 100
#   site    = var.site
# }

# Example: Create a firewall group
# resource "unifi_firewall_group" "example" {
#   name = "Example-Group"
#   type = "address-group"
#   members = [
#     "192.168.1.10",
#     "192.168.1.20"
#   ]
#   site = var.site
# }

# Example: Create a firewall rule
# resource "unifi_firewall_rule" "example" {
#   name    = "Example Rule"
#   action  = "accept"
#   ruleset = "LAN_IN"
#   
#   protocol = "tcp"
#   
#   src_firewall_group_ids = [unifi_firewall_group.example.id]
#   dst_port               = "22"
#   
#   site = var.site
# }

# Example: Get user groups
# data "unifi_user_group" "default" {
#   name = "Default"
#   site = var.site
# }