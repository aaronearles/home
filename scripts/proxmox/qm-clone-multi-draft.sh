#!/bin/bash
#Ask the user for VMID and VMNAME
function pause(){
   read -p "$*"
}
srcvmid=100
dstvmids="101 102 103 104 105 106 107 108 109"
basename=test-server
#sku=tiny
#Call $args from source file based upon SKU name in current directory.
#source ./$sku
clear
echo
echo Existing VMs for reference:
echo
qm list
echo
#read -p 'Please enter NEW VMID#: ' vmid
array=( $dstvmids )
#array=( 104 105 106 107 108 109 )
echo This will create new VMIDs $dstvmids with a Base Name of $basename from Source Template $srcvmid
echo
pause 'Press [ENTER] key to continue...'
echo
for vmid in "${array[@]}"
do
vmname=${basename}-${vmid}
echo
echo Creating $basename VM with ID# $vmid and name of $vmname...
echo
sudo qm clone $srcvmid $vmid --name $vmname
echo
qm start $vmid
echo
done
echo Rebooting in 120...
sleep 30
echo Rebooting in 90...
sleep 30
echo Rebooting in 60...
sleep 30
echo Rebooting in 30...
sleep 20
echo Rebooting in 10...
sleep 5
echo Rebooting in 5...
sleep 1
echo Rebooting in 4...
sleep 1
echo Rebooting in 3...
sleep 1
echo Rebooting in 2...
sleep 1
echo Rebooting in 1...
sleep 1
echo REBOOT SEQUENCE STARTING NOW
echo
for vmid in "${array[@]}"
do
echo
echo Rebooting $vmid
echo
qm reboot $vmid
echo
done