## Status
Updated and tested deploy on 01/12/2025. Terraform Apply hangs at "Still Creating" but VMs are created successfully. However, they take a long time to boot waiting for network connectivity and then I cannot login due to unknown password.

A quick test of cloning 8001 to 100 confirms the image boots and establishes network connectivity successfully, runs cloud-init, testing agent=0 next deploy.

Still don't know the console password but I can SSH using private key.

With agent=0 the apply completes with warning and VM's are created successfully.

```
│ Warning: Qemu Guest Agent support is disabled from proxmox config.
│
│   with proxmox_vm_qemu.vm["key_601"],
│   on vm.tf line 1, in resource "proxmox_vm_qemu" "vm":
│    1: resource "proxmox_vm_qemu" "vm" {
│
│ Qemu Guest Agent support is required to make communications with the VM
│
│ (and 3 more similar warnings elsewhere)
```
However, they're still delayed during boot for network connectivity and cloud-init fails to run...

I noticed that the 600-603 VM's say "No cloud-init drive found" in the management UI, but the 8001-->100 clone had the data populated for cloud-init post deploy.
<!-- Fixed with os_type = "cloud-init" -->
Nope... cloud-init section and IDE2 disk was initially there and then disappeared, still delayed at boot for network...

Upgrading provider to rc6 allowed me to add the ide2 cloudinit disk and successfully deploys the VMs with cloud-init disks but Terraform Apply fails with:

```
│ Error: error updating VM: 500 invalid bootorder: device 'net0' does not exist', error status: {"data":null} (params: map[agent:0 balloon:0 bios:seabios boot:order=scsi0;net0 cicustom: ciupgrade:0 cores:2 cpu:host delete:ciuser,cipassword,searchdomain,nameserver,ipconfig0,shares,serial0,net0 description:Managed by Terraform. hotplug:network,disk,usb kvm:true memory:4096 name:k3s-test-602 numa:0 onboot:false protection:false scsi0:local-lvm:vm-602-disk-0,backup=0,cache=none,discard=on,iothread=1,ssd=1 scsihw:virtio-scsi-single sockets:1 sshkeys:%0A tablet:true vmid:602])
│
│   with proxmox_vm_qemu.vm["key_602"],
│   on vm.tf line 1, in resource "proxmox_vm_qemu" "vm":
│    1: resource "proxmox_vm_qemu" "vm" {
```

The cloud-init UI shows changes made to the config and the VMs shut down. A manual start results in cloud-init section blanking out again...

╷```
│ Warning: Cloud-init is enabled but no IP config is set
│
│   with proxmox_vm_qemu.vm["key_600"],
│   on vm.tf line 1, in resource "proxmox_vm_qemu" "vm":
│    1: resource "proxmox_vm_qemu" "vm" {
│
│ Cloud-init is enabled in your configuration but no static IP address is set, nor is the DHCP option 
│ enabled
```