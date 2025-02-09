## NTXLAB VM
Requires 3 Disks, 32GB, 200GB, 200GB
"Requires 32GB" I gave it 24GB, 20GB was really tight.
E1000 NIC
HOST CPU


https://portal.nutanix.com/page/documents/details?targetId=Nutanix-Community-Edition-Getting-Started
https://community.veeam.com/blogs-and-podcasts-57/nutanix-community-edition-in-proxmox-part-1-initial-setup-7045
https://www.lets-talk-about.tech/2018/01/nutanix-ce-how-to-reduce-cvm-memory.html
    ^ This didn't work, this is what did:
    `virsh list --all`
    `virsh shutdown NTNX-ec55c930-A-CVM`
    `virsh setmem NTNX-ec55c930-A-CVM 8G --config` (seemed OK)
    `virsh setmaxmem NTNX-ec55c930-A-CVM 8G --config` (ERROR)
    `virsh dominfo NTNX-ec55c930-A-CVM` (confirmed unsuccessful)
    `virsh edit NTNX-ec55c930-A-CVM` and use Vi to edit Max Memory to `8388608`
    `virsh dominfo NTNX-ec55c930-A-CVM` confirms successful
    `virsh start NTNX-ec55c930-A-CVM` to start

Proper shutdown:
https://portal.nutanix.com/page/documents/details?targetId=AHV-Admin-Guide-v6_8:ahv-cluster-shut-down-t.html


https://download.nutanix.com/ce/2024.08.19/phoenix.x86_64-fnd_5.6.1_patch-aos_6.8.1_ga.iso
https://download.nutanix.com/virtIO/1.2.3/Nutanix-VirtIO-1.2.3-x64.msi
https://download.nutanix.com/virtIO/1.2.3/Nutanix-VirtIO-1.2.3-x86.msi
https://download.nutanix.com/virtIO/1.2.3/Nutanix-VirtIO-1.2.3.iso


https://blog.intelligent-ware.com/?p=517 # Exporting Proxmox VM’s to VHD Simplified in 4 Steps – Updated 8/2024

