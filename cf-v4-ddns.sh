#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Cloudflare API Token DDNS
# Usage:
# cf-ddns.sh -k cloudflare-api-token \
#            -h host.example.com \
#            -z example.com \
#            -t A|AAAA

# =========================
# Default config
# =========================

# Cloudflare API Token
CFKEY=

# Zone name
CFZONE_NAME=

# Hostname
CFRECORD_NAME=

# Record type
CFRECORD_TYPE=A

# TTL
CFTTL=120

# Force update
FORCE=false

WANIPSITE="http://ipv4.icanhazip.com"


# =========================
# Get parameters
# =========================

while getopts k:h:z:t:f: opts; do
  case ${opts} in
    k) CFKEY=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
  esac
done


# =========================
# Check params
# =========================

if [ "$CFKEY" = "" ]; then
  echo "Missing Cloudflare API Token"
  echo "Use -k TOKEN"
  exit 2
fi

if [ "$CFRECORD_NAME" = "" ]; then
  echo "Missing hostname"
  exit 2
fi

if [ "$CFZONE_NAME" = "" ]; then
  echo "Missing zone"
  exit 2
fi


# =========================
# IPv4 / IPv6
# =========================

if [ "$CFRECORD_TYPE" = "A" ]; then
  WANIPSITE="http://ipv4.icanhazip.com"
elif [ "$CFRECORD_TYPE" = "AAAA" ]; then
  WANIPSITE="http://ipv6.icanhazip.com"
else
  echo "Invalid record type"
  exit 2
fi


# =========================
# FQDN check
# =========================

if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && \
   ! [ -z "${CFRECORD_NAME##*$CFZONE_NAME}" ]; then

  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
  echo "Hostname converted to $CFRECORD_NAME"

fi


# =========================
# Get WAN IP
# =========================

WAN_IP=$(curl -s "$WANIPSITE")

WAN_IP_FILE=$HOME/.cf-wan_ip_$CFRECORD_NAME.txt


if [ -f "$WAN_IP_FILE" ]; then
    OLD_WAN_IP=$(cat "$WAN_IP_FILE")
else
    OLD_WAN_IP=""
fi


if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
    echo "WAN IP unchanged"
    exit 0

    # =========================
# Get Cloudflare IDs
# =========================

ID_FILE=$HOME/.cf-id_$CFRECORD_NAME.txt

if [ -f "$ID_FILE" ] && \
   [ "$(wc -l < "$ID_FILE")" = "4" ] && \
   [ "$(sed -n '3p' "$ID_FILE")" = "$CFZONE_NAME" ] && \
   [ "$(sed -n '4p' "$ID_FILE")" = "$CFRECORD_NAME" ]; then

    CFZONE_ID=$(sed -n '1p' "$ID_FILE")
    CFRECORD_ID=$(sed -n '2p' "$ID_FILE")

else

    echo "Updating zone_identifier & record_identifier"


    # Get Zone ID
    CFZONE_ID=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
    -H "Authorization: Bearer $CFKEY" \
    -H "Content-Type: application/json" \
    | grep -Po '(?<="id":")[^"]*' | head -1)


    if [ -z "$CFZONE_ID" ]; then
        echo "Failed to get Zone ID"
        exit 1
    fi


    # Get Record ID
    CFRECORD_ID=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" \
    -H "Authorization: Bearer $CFKEY" \
    -H "Content-Type: application/json" \
    | grep -Po '(?<="id":")[^"]*' | head -1)


    if [ -z "$CFRECORD_ID" ]; then
        echo "Failed to get DNS Record ID"
        exit 1
    fi


    echo "$CFZONE_ID" > "$ID_FILE"
    echo "$CFRECORD_ID" >> "$ID_FILE"
    echo "$CFZONE_NAME" >> "$ID_FILE"
    echo "$CFRECORD_NAME" >> "$ID_FILE"

fi



# =========================
# Update DNS
# =========================

echo "Updating DNS to $WAN_IP"


RESPONSE=$(curl -s -X PUT \
"https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
-H "Authorization: Bearer $CFKEY" \
-H "Content-Type: application/json" \
--data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\",\"ttl\":$CFTTL}")


if echo "$RESPONSE" | grep -q '"success":true'; then

    echo "Updated successfully!"
    echo "$WAN_IP" > "$WAN_IP_FILE"
    exit 0

else

    echo "Something went wrong :("
    echo "Response:"
    echo "$RESPONSE"
    exit 1

fi
fi
