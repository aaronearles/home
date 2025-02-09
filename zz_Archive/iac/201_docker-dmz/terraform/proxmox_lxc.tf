########## LXC CONFIGURATION ##########

resource "proxmox_lxc" "basic" {
  target_node = var.target_node
  hostname    = var.lxc_hostname
  vmid        = var.lxc_vmid
  # ostemplate   = var.ostemplate
  # password     = var.lxc_password
  unprivileged = var.lxc_unprivileged
  start        = var.lxc_start
  onboot       = var.lxc_onboot
  cores        = var.lxc_cores
  memory       = var.lxc_memsize
  swap         = var.lxc_swap

  clone = "900" //debian-12-template (updated 08092024 w/ curl and sysprep.sh)

  rootfs {
    storage = var.lxc_storage
    size    = var.lxc_disksize
  }

  features {
    fuse    = var.lxc_features.fuse
    keyctl  = var.lxc_features.keyctl
    nesting = var.lxc_features.nesting
    # mount   = var.lxc_features.mount //privileged only
  }

  network {
    name   = var.lxc_network.interface_name
    bridge = var.lxc_network.bridge
    tag    = var.lxc_network.vlan
    ip = "${var.lxc_network.subnet}${var.lxc_vmid}${var.lxc_network.cidr}"
    gw = var.lxc_network.gw
  }

}