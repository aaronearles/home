#!/bin/bash

# Set your OpenAI API key
API_KEY=""

# Define your VPN parameters
PEER_IP_ADDRESSES='["192.168.1.1", "192.168.1.2"]'
LOCAL_ENC_DOMAIN="10.0.0.0/24"
REMOTE_ENC_DOMAIN="10.1.0.0/24"
PHASE1_ENC_ALGO="AES-256"
PHASE1_HASH_ALGO="SHA-256"
PHASE1_DH_GROUP="14"
PHASE1_LIFETIME="28800"
PHASE2_ENC_ALGO="AES-256"
PHASE2_HASH_ALGO="SHA-256"
PHASE2_PFS_GROUP="14"
PHASE2_LIFETIME="3600"
PLATFORM="Palo Alto"
# PLATFORM="Cisco IOS"
# PLATFORM="Terraform for Azure vWAN VPN Site"

# Create the prompt
read -r -d '' PROMPT <<EOF
Generate a VPN configuration for the following parameters on a $PLATFORM platform:
Peer IP Addresses: $PEER_IP_ADDRESSES
Local Encryption Domain: $LOCAL_ENC_DOMAIN
Remote Encryption Domain: $REMOTE_ENC_DOMAIN
Phase 1 Encryption Algorithm: $PHASE1_ENC_ALGO
Phase 1 Hashing Algorithm: $PHASE1_HASH_ALGO
Phase 1 DH Group: $PHASE1_DH_GROUP
Phase 1 SA Lifetime: $PHASE1_LIFETIME
Phase 2 Encryption Algorithm: $PHASE2_ENC_ALGO
Phase 2 Hashing Algorithm: $PHASE2_HASH_ALGO
Phase 2 PFS Group: $PHASE2_PFS_GROUP
Phase 2 SA Lifetime: $PHASE2_LIFETIME
Provide the complete configuration script.
EOF

# Create the JSON payload for the API request
JSON_PAYLOAD=$(jq -n --arg model "gpt-4o-mini" --arg prompt "$PROMPT"\
  '{
    model: $model,
    messages: [
      {
        role: "system",
        content: "You are a VPN configuration script generator."
      },
      {
        role: "user",
        content: $prompt
      }
    ],
    max_tokens: 1024
  }')

# Make the OpenAI API request with curl
response=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "$JSON_PAYLOAD")

# Extract and print the configuration script from the response
configuration_script=$(echo "$response" | jq -r '.choices[0].message.content')
echo "$configuration_script"