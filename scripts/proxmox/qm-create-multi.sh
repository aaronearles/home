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
#read -p 'Please enter NEW VMID#: ' vmid
array=( 100 101 102 103 104 105 106 107 108 109 )
for vmid in "${array[@]}"
do
#read -p 'Please enter NEW VM NAME: ' vmname
vmname=${sku}-vm${vmid}
#echo Please enter NEW VMID#: && read vmid
#echo Please enter NEW VM Name: && read vmname
echo
echo Creating $sku VM with ID# $vmid and name of $vmname...
echo
#pause 'Press [ENTER] key to continue...'
echo
sudo qm create $vmid --name $vmname $args
echo
qm start $vmid
echo
done