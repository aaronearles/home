➜  ~ cat /usr/local/bin/ddns
#!/bin/bash
##### SETUP VARIABLES #####
ZONEID="3df85645994c6bd1399d9a2221ef6213" #EARLES.IO ZONE
RECORDID="feed141277baac2b1c7dd2d72eae6801" #MASTER.EARLES.IO RECORD
#RECORDID="983597cbb894f749892aa5163152b03c" #VPN.EARLES.IO RECORD
TOKEN="" #cloudflare-pve-earlesio-ddns
NAME="master.earles.io"
#NAME="vpn.earles.io"
NTFYTOPIC="aearles_alerts"
LOGPATH="/var/log/ddns.log"
#####  END VARIABLES  #####

#set current timestamp
now=$(date)

# Check for current external IP
#IP=`dig +short txt ch whoami.cloudflare @1.0.0.1| tr -d '"'` #This stopped working due to DNS inspection with Unifi Network 9.3 update
#IP=`curl -s https://ifconfig.io`
IP=$(curl -s --max-time 10 https://ifconfig.io)

# Validate IP before doing anything
if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    err="ERROR: $NAME could not get external IP (got: '$IP') at $now. Skipping."
    echo $err >> $LOGPATH && curl -d "$err" "ntfy.sh/$NTFYTOPIC"
    exit 1
fi


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
#    echo "No change to $IP at $now."
echo "No change to $IP at $now." >> $LOGPATH
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