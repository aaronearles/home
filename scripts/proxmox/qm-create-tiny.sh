#!/bin/bash
#Ask the user for VMID and VMNAME
function pause(){
   read -p "$*"
}
sku=tiny
#Call $args from source file based upon SKU name in current directory.
source ./$sku
clear
echo
echo Existing VMs for reference:
echo
qm list
echo
read -p 'Please enter NEW VMID#: ' vmid
read -p 'Please enter NEW VM NAME: ' vmname
#echo Please enter NEW VMID#: && read vmid
#echo Please enter NEW VM Name: && read vmname
echo
echo Creating $sku VM with ID# $vmid and name of $vmname...
echo
pause 'Press [ENTER] key to continue...'
echo
sudo qm create $vmid --name $vmname $args
echo
qm start $vmid
echo