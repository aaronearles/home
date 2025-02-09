#!/bin/bash
##### SETUP VARIABLES #####
ZONEID="3df85645994c6bd1399d9a2221ef6213" #EARLES.IO ZONE
RECORDID="983597cbb894f749892aa5163152b03c" #VPN.EARLES.IO RECORD
TOKEN="" #cloudflare-pve-earlesio-ddns
NAME="vpn.earles.io"
NTFYTOPIC="aearles_alerts"
LOGPATH="/var/log/ddns.log"
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
    SUCCESS=$(echo $RESULT | jq '.success')
    if [ "$SUCCESS" = "true" ]; then
        msg="$NAME successfully updated to $IP at $now. (Previous record was $IP_CF)" #Considering adding $RESULT | jq '.success' and $IP_CF to either ntfy and/or log
        echo $msg >> $LOGPATH && curl -d "$msg" "ntfy.sh/$NTFYTOPIC"
    else
        ERRORMSG=$(echo $RESULT | jq '.errors[0].message')
        msg="ERROR: $NAME was unable to update to $IP at $now. Error Message: $ERRORMSG see /var/log/ddns.log"
        echo $msg >> $LOGPATH && curl -d "$msg" "ntfy.sh/$NTFYTOPIC"
        echo $RESULT >> $LOGPATH
    fi
fi