# Example outputs - uncomment and modify as needed

# output "site_id" {
#   description = "The ID of the Unifi site"
#   value       = data.unifi_site.default.name
# }

output "networks" {
  description = "Default Network"
  value       = data.unifi_network.default_network
}

# output "devices" {
#   description = "List of devices in the site"
#   value       = data.unifi_device.all
# }