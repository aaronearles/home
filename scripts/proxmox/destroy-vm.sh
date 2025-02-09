#!/bin/bash
function pause(){
   read -p "$*"
}
vmid=$1
#array=( 100 101 102 103 104 105 106 107 108 109 )
#for vmid in "${array[@]}"
#do
echo
echo This will DESTROY VM $vmid, are you sure?
echo
pause 'Press [ENTER] key to continue...'
     qm stop "$vmid"
     qm destroy "$vmid" --skiplock -purge
#done