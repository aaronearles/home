
variable "target_node" {
  type        = string
  description = "Required The name of the Proxmox Node on which to place the VM."
  # default     = "pve"
}

variable "lxc_vmid" {
  type        = string
  description = "VMID# for a single lxc"
}

variable "ostemplate" {
  type        = string
  description = "Path of source CT Template image"
}

variable "lxc_storage" {
  type        = string
  description = "PVE Storage Location"
}

variable "lxc_disksize" {
  type        = string
  description = "Disk size for container. Such as '8G'"
  # default     = "8G"
}

variable "lxc_unprivileged" {
  type        = bool
  description = "Unprivileged container?"
  default     = true
}

variable "lxc_start" {
  type        = bool
  description = "Start upon creation?"
  default     = true
}

variable "lxc_onboot" {
  type        = bool
  description = "Start upon PVE boot?"
  default     = false
}

variable "lxc_cores" {
  type        = string
  description = "Number of CPU cores to allocate to container. Such as '1'"
  default     = 1
}

variable "lxc_memsize" {
  type        = string
  description = "Memory size for container. Such as '512'"
  default     = "512"
}

variable "lxc_swap" {
  type        = string
  description = "Swap memory size available for container. Such as '512'"
  default     = "512"
}

variable "lxc_hostname" {
  type        = string
  description = "Hostname of container."
}

variable "lxc_password" {
  type        = string
  description = "Password for container"
}

variable "ssh_public_keys" {
  type        = string
  description = "Allowed SSH Keys"
}

variable "lxc_features" {
  type = object({
    fuse    = string
    keyctl  = string
    nesting = string
    # mount          = string //privileged only
  })
}

variable "lxc_network" {
  type = object({
    interface_name = string
    bridge         = string
    vlan           = string // VLAN Tag ID "110"
    subnet         = string // First three octets, ending in "."
    gw             = string // Default gateway
    # last_octet = string // Last octet, number only "201" ### Using VMID instead ###
    cidr = string // CIDR block size "/24"
  })
}