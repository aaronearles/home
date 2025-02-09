#!/bin/bash

# Check for root
if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

#SETUP NECESSARY VARIABLES
#read -p "Enter desired user password: " CLEARTEXT_PASSWORD

# wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2

# Create a new VM
qm create 8003 --memory 2048 --cpu cputype=host --core 2 --name rocky-cloud --net0 virtio,bridge=vmbr0

# Import the cloud image to local-lvm storage
qm importdisk 8003 Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 local-lvm

# Attach the new disk to the vm as a scsi drive on the scsi controller
qm set 8003 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-8003-disk-0

# Add cloud init drive
 qm set 8003 --ide2 local-lvm:cloudinit

# Make the cloud init drive bootable and restrict BIOS to boot from disk only
qm set 8003 --boot c --bootdisk scsi0

# Add serial console
qm set 8003 --serial0 socket --vga serial0

# Configure template options
qm set 8003 --agent 1 --ostype l26
qm set 8003 --ciuser aearles
qm set 8003 --cipassword $(openssl passwd -6 $CLEARTEXT_PASSWORD)
# qm set 8003 --sshkey ~/.ssh/id_rsa.pub
qm set 8003 --sshkeys /home/aearles/.ssh/authorized_keys
qm set 8003 --ipconfig0 ip=dhcp --searchdomain earles.internal
# qm set 8003 --ipconfig0 ip=172.20.110.123/24,gw=172.20.110.1 --searchdomain earles.internal


cat << EOF | sudo tee /var/lib/vz/snippets/rocky.yaml
cloud-config
runcmd:
    - yum update
    - yum install -y qemu-guest-agent
    - systemctl start qemu-guest-agent
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

# Apply rocky.yml
qm set 8003 --cicustom "vendor=local:snippets/rocky.yaml"

qm set 8003 --tags _template,rocky-9.3

qm resize 8003 scsi0 +8G

 qm template 8003

# qm clone 8003 110 --name rocky-cloud-test && qm start 110