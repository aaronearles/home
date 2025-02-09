
variable "target_node" {
  type        = string
  description = "Required The name of the Proxmox Node on which to place the VM."
  default     = "pve"
}

variable "lxc_count" {
  type        = string
  description = "Number of containers to deploy"
  # default     = 1
}

variable "id_start" {
  type        = string
  description = "VM/CT ID Number to start from"
  # default     = 400
}

# variable "lxc_list" {
#   type = list(any)
#   description = "List of server numbers ([01,02,03]) -- Define in terraform.tfvars"
#   default = "[01,02,03]"
# }

variable "ostemplate" {
  type        = string
  description = "Path to CT Template to clone" #"local:vztmpl/ubuntu-20.04-standard_20.04-1_amd64.tar.gz"
  default     = "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"
}

# variable "clone_source" {
#   type = string
#   description = "VMID# of container template to clone" #"901"
# }


variable "lxc_disksize" {
  type        = string
  description = "Disk size for container. Such as '8G'"
  default     = "8G"
}

variable "lxc_cores" {
  type        = string
  description = "Number of CPU cores to allocate to container. Such as '1'"
  default     = 1
}

variable "lxc_memsize" {
  type        = string
  description = "Memory size for container. Such as '512`"
  default     = "512"
}

variable "lxc_hostname_pfx" {
  type        = string
  description = "Hostname prefix of container(s)."
  default     = "lxc_clone"
}

variable "lxc_password" {
  type        = string
  description = "Password for container"
}