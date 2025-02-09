#!/bin/bash

# Check for root
if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

#wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O noble-server-cloudimg-amd64.img

# Create a new VM
qm create 8001 --memory 2048 --cpu cputype=host --core 2 --name noble-cloud --net0 virtio,bridge=vmbr0

# Import the cloud image to local-lvm storage
qm importdisk 8001 noble-server-cloudimg-amd64.img local-lvm

# Attach the new disk to the vm as a scsi drive on the scsi controller
qm set 8001 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-8001-disk-0

# Add cloud init drive
 qm set 8001 --ide2 local-lvm:cloudinit

# Make the cloud init drive bootable and restrict BIOS to boot from disk only
qm set 8001 --boot c --bootdisk scsi0

# Add serial console
qm set 8001 --serial0 socket --vga serial0

# Configure template options
qm set 8001 --agent 1 --ostype l26
qm set 8001 --ciuser aearles
qm set 8001 --cipassword $(openssl passwd -6 $CLEARTEXT_PASSWORD)
# qm set 8001 --sshkey ~/.ssh/id_rsa.pub
qm set 8001 --sshkeys /home/aearles/.ssh/authorized_keys
qm set 8001 --ipconfig0 ip=dhcp --searchdomain earles.internal
# qm set 8001 --ipconfig0 ip=172.20.110.123/24,gw=172.20.110.1 --searchdomain earles.internal


#cat << EOF | sudo tee /var/lib/vz/snippets/noble.yaml
#cloud-config
#runcmd:
#    - apt update
#    - apt install -y qemu-guest-agent
#    - systemctl start qemu-guest-agent
#    - reboot
# # Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
#EOF

# Apply vendor.yml
qm set 8001 --cicustom "vendor=local:snippets/ubuntu.yaml"

qm set 8001 --tags _template,ubuntu-24.04

qm resize 8001 scsi0 +8.5G

qm template 8001

qm clone 8001 100 --name noble-cloud-test && qm start 100