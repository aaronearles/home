#!/bin/bash
set -euo pipefail

# Check for root
if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

ID=8005
IMG=debian-13-genericcloud-amd64.qcow2
BASE=https://cloud.debian.org/images/cloud/trixie/latest

# Download and verify cloud image
curl -fsSLO $BASE/$IMG
curl -fsSLO $BASE/SHA512SUMS
grep " $IMG\$" SHA512SUMS | sha512sum -c -

# Seed authorized_keys from GitHub (one-time, not kept in sync)
curl -fsS https://github.com/aaronearles.keys > gh.keys

# Create a new VM
qm create $ID --memory 2048 --cpu cputype=host --cores 2 --name debian13-cloud --net0 virtio,bridge=vmbr0

# Import the cloud image to local-lvm storage
qm importdisk $ID $IMG local-lvm

# Attach the new disk to the vm as a scsi drive on the scsi controller
qm set $ID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$ID-disk-0

# Add cloud init drive
qm set $ID --ide2 local-lvm:cloudinit

# Make the cloud init drive bootable and restrict BIOS to boot from disk only
qm set $ID --boot c --bootdisk scsi0

# Add serial console
qm set $ID --serial0 socket --vga serial0

# Configure template options
qm set $ID --agent 1 --ostype l26
qm set $ID --ciuser aearles
qm set $ID --cipassword $(openssl passwd -6 $CLEARTEXT_PASSWORD)
qm set $ID --sshkeys gh.keys
qm set $ID --ipconfig0 ip=dhcp --searchdomain earles.internal

# Apply vendor data (snippets/cloud-base.yaml -> /var/lib/vz/snippets/)
qm set $ID --cicustom "vendor=local:snippets/cloud-base.yaml"

qm set $ID --tags _template,debian-13

qm resize $ID scsi0 10752M

qm template $ID

rm -f $IMG SHA512SUMS gh.keys
