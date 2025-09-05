# variable "unifi_username" {
#   description = "Username for Unifi Controller"
#   type        = string
#   sensitive   = true
# }

# variable "unifi_password" {
#   description = "Password for Unifi Controller"
#   type        = string
#   sensitive   = true
# }

variable "unifi_api_key" {
  description = "API Key for Unifi Controller"
  type        = string
  sensitive   = true
}

variable "unifi_api_url" {
  description = "URL for Unifi Controller API (e.g., https://unifi:8443)"
  type        = string
}

variable "unifi_allow_insecure" {
  description = "Allow insecure connections (useful for self-signed certificates)"
  type        = bool
  default     = false
}

variable "site" {
  description = "Unifi site name"
  type        = string
  default     = "default"
}