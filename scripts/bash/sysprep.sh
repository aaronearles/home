#!/bin/bash
# This script will generate a systemctl service unit file that will regenerate SSH host keys on next boot, it will also clear the current machine-id.
SERVICE_FILENAME=regen_ssh_hostkeys.service

# Generate Service File
echo [Unit] >> $SERVICE_FILENAME
echo Description=Regenerate SSH host keys >> $SERVICE_FILENAME
echo Before=ssh.service >> $SERVICE_FILENAME
echo ConditionFileIsExecutable=/usr/bin/ssh-keygen >> $SERVICE_FILENAME
echo  >> $SERVICE_FILENAME
echo [Service] >> $SERVICE_FILENAME
echo Type=oneshot >> $SERVICE_FILENAME
echo ExecStartPre=-/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096 >> $SERVICE_FILENAME
echo ExecStartPre=-/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*" >> $SERVICE_FILENAME
echo ExecStart=/usr/bin/ssh-keygen -A -v >> $SERVICE_FILENAME
echo ExecStartPost=/bin/systemctl disable regenerate_ssh_host_keys >> $SERVICE_FILENAME
echo  >> $SERVICE_FILENAME
echo [Install] >> $SERVICE_FILENAME
echo WantedBy=multi-user.target >> $SERVICE_FILENAME

# Check for Root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Install/Enable Regen Service
chown root:root $SERVICE_FILENAME
mv ./$SERVICE_FILENAME /etc/systemd/system/
systemctl daemon-reload
systemctl enable $SERVICE_FILENAME # WARNING: Next boot, your SSH keys will reset!

# Reset Machine ID
echo -n >/etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id