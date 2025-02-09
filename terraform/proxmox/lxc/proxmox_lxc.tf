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
