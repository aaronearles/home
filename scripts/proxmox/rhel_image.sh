#!/bin/bash

# Check for root
if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

#SETUP NECESSARY VARIABLES
#read -p "Enter desired user password: " CLEARTEXT_PASSWORD

# Elimintated image check because RHEL download requires login

# Create a new VM
qm create 8002 --memory 2048 --cpu cputype=host --core 2 --name rhel-cloud --net0 virtio,bridge=vmbr0

# Import the cloud image to local-lvm storage
qm importdisk 8002 rhel-9.3-x86_64-kvm.qcow2 local-lvm

# Attach the new disk to the vm as a scsi drive on the scsi controller
qm set 8002 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-8002-disk-0

# Add cloud init drive
 qm set 8002 --ide2 local-lvm:cloudinit

# Make the cloud init drive bootable and restrict BIOS to boot from disk only
qm set 8002 --boot c --bootdisk scsi0

# Add serial console
qm set 8002 --serial0 socket --vga serial0

# Configure template options
qm set 8002 --agent 1 --ostype l26
qm set 8002 --ciuser aearles
qm set 8002 --cipassword $(openssl passwd -6 $CLEARTEXT_PASSWORD)
# qm set 8002 --sshkey ~/.ssh/id_rsa.pub
qm set 8002 --sshkeys /home/aearles/.ssh/authorized_keys
qm set 8002 --ipconfig0 ip=dhcp --searchdomain earles.internal
# qm set 8002 --ipconfig0 ip=172.20.110.123/24,gw=172.20.110.1 --searchdomain earles.internal


cat << EOF | sudo tee /var/lib/vz/snippets/rhel.yaml
cloud-config
runcmd:
    - yum update
    - yum install -y qemu-guest-agent
    - systemctl start qemu-guest-agent
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

# Apply rhel.yml
qm set 8002 --cicustom "vendor=local:snippets/rhel.yaml"

qm set 8002 --tags _template,rhel-9.3

qm resize 8002 scsi0 +8G

qm template 8002

qm clone 8002 110 --name rhel-cloud-test && qm start 110