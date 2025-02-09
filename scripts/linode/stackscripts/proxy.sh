#!/bin/sh
#
fqdn="proxy.local"
timezone="UTC"
USER=""
PASSWORD=""
pubkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfgFgJzAiboiYACBkcCVEkc7LRcdT1JD77PQ56uCR5p weston_nt\aearles@LAP121-105863"
sshport="443"
###############################
# Update the package list
apk update && apk upgrade
# Get IP address
ip=`ip route get 1 | egrep -o 'src [[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}' | awk '{print $2;exit}'`
INTERFACE=`cat /etc/network/interfaces | egrep "iface .* static" | awk '{print $2;exit}'`
# Set hostname and fqdn - Source : https://wiki.alpinelinux.org/wiki/Configure_Networking
if [ -n "${fqdn+set}" ]; then
  hostname=`echo $fqdn | awk -F . '{print $1;exit}'`
  echo $hostname > /etc/hostname
  hostname -F /etc/hostname
  echo $ip     $hostname $fqdn | tee -a /etc/hosts
fi
#Set timezone - Source : https://wiki.alpinelinux.org/wiki/Setting_the_timezone
apk add tzdata
cp /usr/share/zoneinfo/$timezone /etc/localtime
echo $timezone > /etc/timezone
apk del tzdata
# Add sudo user
apk add sudo
addgroup sudo
adduser -D $USER
adduser $USER sudo
echo "$USER:$PASSWORD" | chpasswd
sed -i '/%sudo/s/^# //' /etc/sudoers
# Harden SSH access
mkdir -p /home/$USER/.ssh
echo "$pubkey" >> /home/$USER/.ssh/authorized_keys
chmod -R 700 /home/${user}/.ssh
chown -R ${user}:${user} /home/${user}/.ssh
sed -i.orig "s/#Port 22/Port $sshport/" /etc/ssh/sshd_config
sed -i -e "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/#*passwordAuthentication [no]*[yes]*/passwordAuthentication no/" /etc/ssh/sshd_config
sed -i -e "s/#*AllowTcpForwarding [no]*[yes]*/AllowTcpForwarding yes/" /etc/ssh/sshd_config
#sed -i 's/#*GSSAPIAuthentication [no]*[yes]*/GSSAPIAuthentication no/' /etc/ssh/sshd_config
echo 'AddressFamily inet' | tee -a /etc/ssh/sshd_config
sed -i 's/#Banner none/Banner \/etc\/ssh\/banner/' /etc/ssh/sshd_config
# Banner
cat << EOT > /etc/ssh/banner
#################################################################
#       All connections are monitored and recorded              #
#  Disconnect IMMEDIATELY if you are not an authorized user!    #
#################################################################
EOT
echo "" > /etc/motd
rc-service sshd restart
# Install and configure Squid Proxy
apk update
apk add squid
apk add apache2-utils
rm -rf /etc/squid/squid.conf
touch /etc/squid/squid.conf
echo -e "
forwarded_for off
visible_hostname squid.server.commm
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/squid_passwd
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
# Choose the port you want. Below we set it to default 3128.
http_port 127.0.0.1:3128
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access WWW-Authenticate allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Authenticate allow all
request_header_access Cache-Control allow all
request_header_access Content-Encoding allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Expires allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Content-Language allow all
request_header_access Mime-Version allow all
request_header_access Retry-After allow all
request_header_access Title allow all
request_header_access Connection allow all
request_header_access Proxy-Connection allow all
request_header_access User-Agent allow all
request_header_access Cookie allow all
request_header_access All deny all" >> /etc/squid/squid.conf
htpasswd -b -c /etc/squid/squid_passwd $USER $PASSWORD
service squid restart
clear
change
htpasswd -b -c /etc/squid/squid_passwd $USER $PASSWORD