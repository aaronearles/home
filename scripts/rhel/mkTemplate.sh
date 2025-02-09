#!/bin/bash
# This script was obtained here: https://gist.github.com/rch317/3540fb819bff6cfadfaae89cfdc1d7c5
# It's a nice example for VMWare but needs to be updated for my environment and needs further review.
#
# some variables
export ADMIN_USER="aearles"
export ADMIN_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCva5nf9YaVqXzH1hDAHfdpJan80ze3hS5dtoGtWzNe9FGzw8RtUHtML7YGXu+E3I9Yw9dVvC+U8svXjBS1c2re9zNqzI+50RZkpuIlmQPMm315BN07MDcXZ4m5XRR+dGK1zE9F9vBP7/MnC/dFfiIb4pg1NxIb1egeJDeRxPyyeyOm6CnOrxSbKOw8JcGB5N92abgMrEcajNNBhprCMEEMf17iDf626DIADowvjI6f4tkJ2T7n255Z/z+C2XhfPpmjvabE2ebYo2pVyf4KAAOuyBJHcAWtFq1NRrYfoRdKUeUOvfoOHi/cXYeuGFjPs3S2SocEIvJQ3bR4tZlkVuLR"

# install necessary and helpful components
yum -y install net-tools deltarpm wget bash-completion yum-plugin-remove-with-leaves yum-utils

# install VM tools and perl for VMware VM customizations
# yum -y install open-vm-tools perl
yum -y install qemu-guest-agent

# Stop logging services
systemctl stop rsyslog
service auditd stop

# Remove old kernels
package-cleanup -y --oldkernels --count=1

# Clean out yum
yum clean all

# Force the logs to rotate & remove old logs we don’t need
/usr/sbin/logrotate /etc/logrotate.conf --force
rm -f /var/log/*-???????? /var/log/*.gz
rm -f /var/log/dmesg.old
rm -rf /var/log/anaconda

# Truncate the audit logs (and other logs we want to keep placeholders for)
cat /dev/null > /var/log/audit/audit.log
cat /dev/null > /var/log/wtmp
cat /dev/null > /var/log/lastlog
cat /dev/null > /var/log/grubby

# Remove the traces of the template MAC address and UUIDs
sed -i '/^\(HWADDR\|UUID\)=/d' /etc/sysconfig/network-scripts/ifcfg-e* ### This doesn't match my script/doc, needs review ###

# enable network interface onboot
sed -i -e 's@^ONBOOT="no@ONBOOT="yes@' /etc/sysconfig/network-scripts/ifcfg-e* ### This doesn't match my script/doc, needs review ###

# Clean /tmp out
rm -rf /tmp/*
rm -rf /var/tmp/*

# Remove the SSH host keys
rm -f /etc/ssh/*key*

# add user 'ADMIN_USER'
adduser $ADMIN_USER

# add public SSH key
mkdir -m 700 /home/$ADMIN_USER/.ssh
chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
echo $ADMIN_PUBLIC_KEY > /home/$ADMIN_USER/.ssh/authorized_keys
chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh/authorized_keys

# add support for ssh-add
echo 'eval $(ssh-agent) > /dev/null' >> /home/$ADMIN_USER/.bashrc

# add user 'ADMIN_USER' to sudoers
echo "$ADMIN_USER    ALL = NOPASSWD: ALL" > /etc/sudoers.d/$ADMIN_USER
chmod 0440 /etc/sudoers.d/$ADMIN_USER

# Remove the root user’s SSH history
rm -rf ~root/.ssh/
rm -f ~root/anaconda-ks.cfg

# remove the root password
#passwd -d root

# for support guest customization of CentOS 7 in vSphere 5.5 and vCloud Air
# mv /etc/redhat-release /etc/redhat-release.old && touch /etc/redhat-release && echo 'Red Hat Enterprise Linux Server release 7.0 (Maipo)' > /etc/redhat-release

# Remove the root user’s shell history
history -cw

# shutdown
init 0