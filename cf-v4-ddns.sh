#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


# Cloudflare API Token DDNS
#
# Usage:
#
# cf-ddns.sh \
# -k API_TOKEN \
# -z example.com \
# -h sub.example.com \
# -t A


# =========================
# Config
# =========================

CFKEY=""
CFZONE_NAME=""
CFRECORD_NAME=""
CFRECORD_TYPE="A"

CFTTL=120

FORCE="false"


# =========================
# Get IP
# =========================

if [ "$CFRECORD_TYPE" = "AAAA" ]; then
    WANIPSITE="https://ipv6.icanhazip.com"
else
    WANIPSITE="https://ipv4.icanhazip.com"
fi



# =========================
# Arguments
# =========================

while getopts "k:z:h:t:f:" opt
do

case $opt in

k)
    CFKEY="$OPTARG"
    ;;

z)
    CFZONE_NAME="$OPTARG"
    ;;

h)
    CFRECORD_NAME="$OPTARG"
    ;;

t)
    CFRECORD_TYPE="$OPTARG"
    ;;

f)
    FORCE="$OPTARG"
    ;;

*)
    echo "Usage:"
    echo "$0 -k TOKEN -z ZONE -h HOST [-t A|AAAA]"
    exit 2
    ;;

esac

done



# =========================
# Check
# =========================


if [ -z "$CFKEY" ]; then
    echo "Missing Cloudflare API Token"
    exit 2
fi


if [ -z "$CFZONE_NAME" ]; then
    echo "Missing Zone"
    exit 2
fi


if [ -z "$CFRECORD_NAME" ]; then
    echo "Missing Host"
    exit 2
fi



if [ "$CFRECORD_TYPE" != "A" ] &&
   [ "$CFRECORD_TYPE" != "AAAA" ]; then

    echo "Invalid type"
    exit 2

fi



# =========================
# FQDN
# =========================


if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] &&
   [[ "$CFRECORD_NAME" != *"$CFZONE_NAME" ]]; then

    CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"

fi



# =========================
# Get WAN IP
# =========================


if [ "$CFRECORD_TYPE" = "AAAA" ]; then

    WAN_IP=$(curl -s https://ipv6.icanhazip.com | tr -d '\r\n')

else

    WAN_IP=$(curl -s https://ipv4.icanhazip.com | tr -d '\r\n')

fi



if [ -z "$WAN_IP" ]; then

    echo "Failed get WAN IP"
    exit 1

fi



echo "Current IP: $WAN_IP"



# =========================
# IP Cache
# =========================


WAN_IP_FILE="$HOME/.cf-wan_ip_$CFRECORD_NAME.txt"


OLD_WAN_IP=""


if [ -f "$WAN_IP_FILE" ]; then

    OLD_WAN_IP=$(cat "$WAN_IP_FILE")

fi



echo "Old IP: $OLD_WAN_IP"



if [[ "$WAN_IP" == "$OLD_WAN_IP" ]] &&
   [[ "$FORCE" == "false" ]]; then

    echo "WAN IP unchanged"
    exit 0

fi

# =========================
# Cloudflare API Headers
# =========================

AUTH_HEADER="Authorization: Bearer $CFKEY"


# =========================
# Get Zone ID / Record ID
# =========================

ID_FILE="$HOME/.cf-id_$CFRECORD_NAME.txt"


if [ -f "$ID_FILE" ] && \
   [ "$(wc -l < "$ID_FILE")" -eq 4 ] && \
   [ "$(sed -n '3p' "$ID_FILE")" = "$CFZONE_NAME" ] && \
   [ "$(sed -n '4p' "$ID_FILE")" = "$CFRECORD_NAME" ]; then


    CFZONE_ID=$(sed -n '1p' "$ID_FILE")
    CFRECORD_ID=$(sed -n '2p' "$ID_FILE")


    echo "Using cached IDs"


else


    echo "Getting Cloudflare IDs..."


    CFZONE_ID=$(curl -s \
    -X GET \
    "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    | grep -Po '(?<="id":")[^"]*' \
    | head -1)



    if [ -z "$CFZONE_ID" ]; then

        echo "Failed to get Zone ID"

        exit 1

    fi



    CFRECORD_ID=$(curl -s \
    -X GET \
    "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    | grep -Po '(?<="id":")[^"]*' \
    | head -1)



    if [ -z "$CFRECORD_ID" ]; then

        echo "Failed to get Record ID"

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


echo "Updating DNS..."



RESPONSE=$(curl -s \
-X PUT \
"https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
-H "$AUTH_HEADER" \
-H "Content-Type: application/json" \
--data "{
\"type\":\"$CFRECORD_TYPE\",
\"name\":\"$CFRECORD_NAME\",
\"content\":\"$WAN_IP\",
\"ttl\":$CFTTL
}")



if echo "$RESPONSE" | grep -q '"success":true'; then


    echo "DNS update successful"

    echo "$WAN_IP" > "$WAN_IP_FILE"


else


    echo "DNS update failed"

    echo "$RESPONSE"

    exit 1


fi
