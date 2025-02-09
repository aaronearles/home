ZONEID=""
TOKEN=""
URL="https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records"
curl --request GET --url $URL -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}"