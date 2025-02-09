#!/bin/bash

##### SETUP VARIABLES #####
ZONEID="" #https://developers.cloudflare.com/api/operations/zones-get
RECORDID="" #https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-list-dns-records
TOKEN="" #Cloudflare API Token w/ Zone Edit permissions
NAME="" #Name of DNS Record (ie. xyz.domain.com)
NTFYTOPIC="" #NTFY.SH Notification Topic to publish updates to
LOGPATH="/var/log/ddns.log" #file path to log events
#####  END VARIABLES  #####

#set current timestamp
now=$(date)

# Check for current external IP
IP=`dig +short txt ch whoami.cloudflare @1.0.0.1| tr -d '"'`

# Set Cloudflare API
URL="https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records/$RECORDID"

# Connect to Cloudflare
cf() {
curl -X ${1} "${URL}" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${TOKEN}" \
      ${2} ${3}
}

# Get current DNS data
RESULT=$(cf GET)
IP_CF=$(jq -r '.result.content' <<< ${RESULT})

# Compare IPs
if [ "$IP" = "$IP_CF" ]; then
    echo "No change to $IP at $now."
else
    RESULT=$(cf PUT --data "{\"type\":\"A\",\"name\":\"${NAME}\",\"content\":\"${IP}\"}")
    msg="$NAME updated to $IP at $now."
    echo $msg >> $LOGPATH && curl -d "$msg" "ntfy.sh/$NTFYTOPIC"
    fi