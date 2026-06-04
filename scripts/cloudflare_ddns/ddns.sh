#!/bin/bash
# Script: ddns.sh
# Purpose: Cloudflare DDNS updater with retry logic and request jitter
# Usage: ddns.sh <env-file>
# Dependencies: curl, jq
# Example: ddns.sh /etc/ddns/master.env
#          */5 * * * * /usr/local/bin/ddns /etc/ddns/master.env

set -uo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly IP_PROVIDERS=(
  "https://ifconfig.io"
  "https://api.ipify.org"
  "https://icanhazip.com"
)
readonly MAX_RETRIES=3
readonly MAX_JITTER=30

usage() {
  printf "Usage: %s <env-file>\n" "$SCRIPT_NAME" >&2
  exit 1
}

log() {
  printf "%s\n" "$1" >> "$LOGPATH"
}

notify() {
  curl -sf -d "$1" "ntfy.sh/$NTFYTOPIC" > /dev/null 2>&1 || true
}

get_external_ip() {
  local ip=""
  local attempt=0
  local backoff=2

  while (( attempt < MAX_RETRIES )); do
    for provider in "${IP_PROVIDERS[@]}"; do
      ip=$(curl -sf --max-time 10 "$provider" 2>/dev/null | tr -d '[:space:]')
      if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf "%s" "$ip"
        return 0
      fi
    done
    (( attempt++ ))
    if (( attempt < MAX_RETRIES )); then
      local wait=$(( backoff + RANDOM % backoff ))
      sleep "$wait"
      (( backoff *= 2 ))
    fi
  done

  return 1
}

cf_api() {
  local method="$1"
  shift
  curl -sf -X "$method" "$CF_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    "$@"
}

main() {
  if [[ $# -lt 1 || ! -f "$1" ]]; then
    usage
  fi

  # shellcheck source=/dev/null
  source "$1"

  for var in ZONEID RECORDID TOKEN NAME NTFYTOPIC LOGPATH; do
    if [[ -z "${!var:-}" ]]; then
      printf "Error: %s is not set in %s\n" "$var" "$1" >&2
      exit 1
    fi
  done

  readonly CF_URL="https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records/$RECORDID"
  local now
  now=$(date)

  # Random delay to avoid thundering herd on round-minute cron
  sleep $(( RANDOM % MAX_JITTER ))

  local ip
  if ! ip=$(get_external_ip); then
    local err="ERROR: $NAME could not get external IP after $MAX_RETRIES retry attempts at $now. Skipping."
    log "$err"
    notify "$err"
    exit 1
  fi

  local result ip_cf
  if ! result=$(cf_api GET); then
    local err="ERROR: $NAME failed to query Cloudflare API at $now."
    log "$err"
    notify "$err"
    exit 1
  fi
  ip_cf=$(jq -r '.result.content' <<< "$result")

  if [[ "$ip" == "$ip_cf" ]]; then
    log "No change to $ip at $now."
    return 0
  fi

  result=$(cf_api PUT --data "{\"type\":\"A\",\"name\":\"$NAME\",\"content\":\"$ip\"}")
  local success
  success=$(jq -r '.success' <<< "$result")

  if [[ "$success" == "true" ]]; then
    local msg="$NAME successfully updated to $ip at $now. (Previous record was $ip_cf)"
    log "$msg"
    notify "$msg"
  else
    local error_msg
    error_msg=$(jq -r '.errors[0].message' <<< "$result")
    local msg="ERROR: $NAME failed to update to $ip at $now. Error: $error_msg — see $LOGPATH"
    log "$msg"
    notify "$msg"
    log "$result"
    exit 1
  fi
}

main "$@"
