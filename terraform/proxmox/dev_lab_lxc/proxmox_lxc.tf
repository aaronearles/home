########## LXC CONFIGURATION ##########

resource "proxmox_lxc" "basic" {
  count = var.lxc_count
  # for_each            = { for i in var.lxc_list : "key_${i}" => i }
  target_node = var.target_node
  hostname    = "${var.lxc_hostname_pfx}-${count.index + var.id_start}" //count. ${count.index + 1} if starting at 1
  # hostname     = "${var.lxc_hostname_pfx}-${format("%04d", each.value)}"
  vmid         = count.index + var.id_start
  ostemplate   = var.ostemplate
  password     = var.lxc_password
  unprivileged = true
  start        = true
  cores        = var.lxc_cores
  memory       = var.lxc_memsize

  ssh_public_keys = <<-EOT
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCva5nf9YaVqXzH1hDAHfdpJan80ze3hS5dtoGtWzNe9FGzw8RtUHtML7YGXu+E3I9Yw9dVvC+U8svXjBS1c2re9zNqzI+50RZkpuIlmQPMm315BN07MDcXZ4m5XRR+dGK1zE9F9vBP7/MnC/dFfiIb4pg1NxIb1egeJDeRxPyyeyOm6CnOrxSbKOw8JcGB5N92abgMrEcajNNBhprCMEEMf17iDf626DIADowvjI6f4tkJ2T7n255Z/z+C2XhfPpmjvabE2ebYo2pVyf4KAAOuyBJHcAWtFq1NRrYfoRdKUeUOvfoOHi/cXYeuGFjPs3S2SocEIvJQ3bR4tZlkVuLR
  EOT

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "local-lvm"
    size    = var.lxc_disksize
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

}
