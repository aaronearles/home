variable "linode_token" {
  type        = string
  description = "Linode API Token used in provider.tf"
  sensitive   = true
}

variable "instance_label" {
  type        = string
  description = "Label for instance"
}

variable "image" {
  type        = string
  description = "Image for OS"
  # default     = "linode/ubuntu22.04"
  default = "linode/rocky10"
}

variable "stackscript_id" {
  type        = string
  description = "Optional: Linode StackScript ID to deploy"
  default     = "" //Empty triggers conditional expression to nullify
}

variable "github_user" {
  type        = string
  description = "GitHub user whose public SSH keys (https://github.com/<user>.keys) are added to authorized_keys. Leave blank to skip and use only authorized_keys"
  nullable    = false
}

variable "authorized_keys" {
  type        = list(string)
  description = "Optional: SSH public keys to add, merged with any GitHub keys"
  default     = []
}

variable "tags" {
  type        = list(string)
  description = "Optional: List of tags to apply"
  default     = []
}

# variable "root_pass" { //Replaced with random_password.root_pass
#   type        = string
#   description = "Password for root account"
# }