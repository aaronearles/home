#!/bin/bash
function pause(){
   read -p "$*"
}
targetvms="105 106 107 108 109"
array=( $targetvms )
echo This will DESTROY VMIDs $targetvms
pause 'Press [ENTER] key to continue...'
for vmid in "${array[@]}"
do
     qm stop "$vmid"
     qm destroy "$vmid" --skiplock -purge
done