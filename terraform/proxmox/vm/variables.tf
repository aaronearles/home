
variable "target_node" {
  type        = string
  description = "Required The name of the Proxmox Node on which to place the VM."
  default     = "pve"
}

variable "instance_count" {
  type        = string
  description = "Number of instances to deploy"
  # default     = 1
}

variable "id_start" {
  type        = string
  description = "VM/CT ID Number to start from"
  # default     = 400
}

# variable "instance_list" {
#   type = list(any)
#   description = "List of server numbers ([01,02,03]) -- Define in terraform.tfvars"
#   default = "[01,02,03]"
# }

variable "clone_source" {
  type = string
  description = "VMID# of template to clone" #"801" //May be name?
  default = "ubuntu-22.04-template"
}

variable "hostname_pfx" {
  type        = string
  description = "Hostname prefix of container(s)."
  default     = "vm"
}

variable "admin_password" {
  type        = string
  description = "Password for container"
}


variable "memory" {
  type        = string
  description = "Memory allocated in MB"
}

variable "sockets" {
  type        = string
  description = "CPU Socket count"
  default = "1"
}

variable "cores" {
  type        = string
  description = "CPU Core count"
  default = "1"
}

variable "vcpus" {
  type        = string
  description = "CPU vCPU count"
  default = "0"
}

variable "os_type" {
  type        = string
  description = "OS Type"
  default = "ubuntu"
}

variable "vm_state" {
  type        = string
  description = "Desired state of VM; running or stopped"
  default = "running"
}

variable "agent" {
  type        = number
  description = "qemu-guest-agent enabled"
  default = "0" //confirmed agent=1 results in stuck @ still creating... try adding agent to base image?
}