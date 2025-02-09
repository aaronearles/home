variable "linode_token" {
  type        = string
  description = "Linode API Token used in provider.tf"
}

variable "instance_label" {
  type        = string
  description = "Label for instance"
}

variable "image" {
  type        = string
  description = "Image for OS"
  default     = "linode/ubuntu22.04"
}

variable "stackscript_id" {
  type        = string
  description = "Optional: Linode StackScript ID to deploy"
  default     = "" //Empty triggers conditional expression to nullify
}

variable "authorized_keys" {
  type        = list(string)
  description = "Authorized SSH Keys"
  default     = [""]
}

variable "tags" {
  type        = list(string)
  description = "List of tags to apply"
  default     = [""]
}

# variable "root_pass" { //Replaced with random_password.root_pass
#   type        = string
#   description = "Password for root account"
# }