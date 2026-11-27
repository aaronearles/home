#!/bin/sh
# Linode StackScript (Alpine): SSH-only squid proxy.
# Managed by OpenTofu (linode_stackscript.proxy) - values are passed in via stackscript_data.
# No secrets or keys live here: the SSH key is copied from root's authorized_keys,
# which Linode populates from the instance's authorized_keys.
#
# <UDF name="SSH_USER" label="Admin username" default="aearles" />
# <UDF name="SSH_PORT" label="SSH port" default="443" />
# <UDF name="FQDN" label="Hostname / FQDN" default="proxy.local" />
# <UDF name="TIMEZONE" label="Timezone" default="UTC" />

exec > /var/log/stackscript.log 2>&1
set -eu

apk update && apk upgrade

# Hostname
HOSTNAME_SHORT="${FQDN%%.*}"
echo "$HOSTNAME_SHORT" > /etc/hostname
hostname -F /etc/hostname
echo "127.0.0.1 $HOSTNAME_SHORT $FQDN" >> /etc/hosts

# Timezone
apk add tzdata
cp "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone
apk del tzdata

# Admin user: key-only login, passwordless sudo.
# (Random throwaway password because sshd refuses pubkey login for locked Alpine accounts.)
apk add sudo
adduser -D "$SSH_USER"
echo "$SSH_USER:$(head -c 32 /dev/urandom | base64)" | chpasswd
addgroup "$SSH_USER" wheel
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

mkdir -p "/home/$SSH_USER/.ssh"
cp /root/.ssh/authorized_keys "/home/$SSH_USER/.ssh/authorized_keys"
chmod 700 "/home/$SSH_USER/.ssh"
chmod 600 "/home/$SSH_USER/.ssh/authorized_keys"
chown -R "$SSH_USER:$SSH_USER" "/home/$SSH_USER/.ssh"

# Harden SSH (drop-in; Alpine's sshd_config Include's sshd_config.d, which is read first)
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/00-proxy.conf << EOT
Port $SSH_PORT
AddressFamily inet
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowTcpForwarding yes
AllowUsers $SSH_USER
Banner /etc/ssh/banner
EOT
cat > /etc/ssh/banner << EOT
#################################################################
#       All connections are monitored and recorded              #
#  Disconnect IMMEDIATELY if you are not an authorized user!    #
#################################################################
EOT
: > /etc/motd
sshd -t
rc-service sshd restart

# Squid: listens on loopback only, reached through the SSH tunnel
apk add squid
cat > /etc/squid/squid.conf << EOT
http_port 127.0.0.1:3128
acl localnet src 127.0.0.1/32
http_access allow localnet
http_access deny all
forwarded_for delete
via off
visible_hostname proxy
cache deny all
EOT
rc-update add squid default
rc-service squid restart
