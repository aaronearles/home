#!/bin/bash

# Check for root
if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

#SETUP NECESSARY VARIABLES
read -p "Enter desired user password: " CLEARTEXT_PASSWORD

# Check if image file is present, download if necessary
if ! test -f ./jammy-server-cloudimg-amd64.img; then
    # Choose a cloud image -- https://cloud-images.ubuntu.com/
    wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
fi

# Create a new VM
qm create 8000 --memory 2048 --core 2 --name ubuntu-cloud --net0 virtio,bridge=vmbr0

# Import the cloud image to local-lvm storage
qm importdisk 8000 jammy-server-cloudimg-amd64.img local-lvm

# Attach the new disk to the vm as a scsi drive on the scsi controller
qm set 8000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-8000-disk-0

# Add cloud init drive
qm set 8000 --ide2 local-lvm:cloudinit

# Make the cloud init drive bootable and restrict BIOS to boot from disk only
qm set 8000 --boot c --bootdisk scsi0

# Add serial console
qm set 8000 --serial0 socket --vga serial0

# Configure template options
qm set 8000 --agent 1 --ostype l26
qm set 8000 --ciuser aearles
qm set 8000 --cipassword $(openssl passwd -6 $CLEARTEXT_PASSWORD)
# qm set 8000 --sshkey ~/.ssh/id_rsa.pub
qm set 8000 --sshkeys /home/aearles/.ssh/authorized_keys
qm set 8000 --ipconfig0 ip=dhcp --searchdomain earles.internal
# qm set 8000 --ipconfig0 ip=172.20.110.123/24,gw=172.20.110.1 --searchdomain earles.internal

# cat << EOF | sudo tee /var/lib/vz/snippets/vendor.yaml
cat << EOF | sudo tee /var/lib/vz/snippets/vendor.yaml
#cloud-config
runcmd:
    - apt update
    - apt install -y qemu-guest-agent
    - systemctl start qemu-guest-agent
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

# Apply vendor.yml
qm set 8000 --cicustom "vendor=local:snippets/vendor.yaml"

qm set 8000 --tags _template,ubuntu-22.04

qm resize 8000 scsi0 8G

qm template 8000

qm clone 8000 201 --name dmz && qm start 201