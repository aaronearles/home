#!/bin/bash
# Tested on RHEL 9.3
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_virtualization/cloning-virtual-machines_configuring-and-managing-virtualization#proc_creating-a-virtual-machine-template-manually_assembly_creating-virtual-machine-templates
rm -f /etc/udev/rules.d/70-persistent-net.rules
# Remove unique information from the NMConnection files in the /etc/NetworkManager/system-connections/ directory.
# In my case there was /etc/NetworkManager/system-connections/ens18.nmconnection that I stripped down to only include:
    # [connection]
    # type=ethernet
    # autoconnect-priority=-999

    # [ethernet]

    # [ipv4]
    # method=auto

    # [ipv6]
    # addr-gen-mode=eui64
    # method=auto

    # [proxy]

# I then renamed (w/ backup copy) the file to ethernet-dhcp.nmconnection

rm /etc/sysconfig/rhn/systemid #Only exists for VMs registered on the Red Hat Network (RHN)

# For VMs registered with Red Hat Subscription Manager (RHSM):
subscription-manager unsubscribe --all
subscription-manager unregister
subscription-manager clean

# Remove other unique details:
rm -rf /etc/ssh/ssh_host_* # Remove SSH public and private key pairs
rm /etc/lvm/devices/system.devices # Remove the configuration of LVM devices

# Remove the gnome-initial-setup-done file to configure the VM to run the configuration wizard on the next boot:
rm ~/.config/gnome-initial-setup-done

# New /etc/machine-id was necessary in Ubuntu due to duplicate DHCP IP's w/ Unifi
# https://access.redhat.com/solutions/3600401
mv /etc/machine-id /tmp/
systemd-machine-id-setup # seems like this should be run post-clone, we'll see.