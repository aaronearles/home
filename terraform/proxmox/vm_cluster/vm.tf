resource "proxmox_vm_qemu" "vm" {
  for_each = { for i in var.instance_list : "key_${i}" => i }
  # count = var.instance_count
  # name        = "VM-name"
  vmid = format("%03d", each.value)
  # name     = "${var.hostname_pfx}-${count.index + var.id_start}" //count. ${count.index + 1} if starting at 1
  name     = "${var.hostname_pfx}-${var.environment}-${format("%03d", each.value)}"
  vm_state = var.vm_state //requires version = "3.0.1-rc1" otherwise use:
  # oncreate      = true //start vm upon creation? deprecated in 3.0.1-rc1
  # name        = "${var.hostname_pfx}-${format("%03d", each.value)}"
  target_node = var.target_node
  # iso         = "ISO file name"

  ### or for a Clone VM operation
  clone      = var.clone_source
  full_clone = false
  scsihw     = "virtio-scsi-single"
  boot       = "order=scsi0;net0"
  disks {
    scsi {
      scsi0 {
        disk {
          backup             = false
          cache              = "none"
          discard            = true
          emulatessd         = true
          iothread           = true
          mbps_r_burst       = 0.0
          mbps_r_concurrent  = 0.0
          mbps_wr_burst      = 0.0
          mbps_wr_concurrent = 0.0
          replicate          = true
          size               = 64
          storage            = "local-lvm"
        }
      }
    }
  }

  ### SPECS ###
  memory  = var.memory
  sockets = var.sockets
  cores   = var.cores
  vcpus   = var.vcpus

  os_type = var.os_type
  agent   = var.agent



}

# resource "ansible_playbook" "playbook" {
#   # count = var.instance_count
#   playbook   = "${path.module}/test_wait.yml"
#   name       = proxmox_vm_qemu.vm[count.index].ssh_host
#   extra_vars = { "ansible_user" = "aearles", "ansible_become_password" = "${var.ansible_become_password}" }
# }