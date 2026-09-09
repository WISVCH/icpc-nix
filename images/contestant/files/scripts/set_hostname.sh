#!/usr/bin/env bash

# Get dev entry mounted as root filesystem
# 
# findmnt: show mountpoints
#     -n:        don't print headers
#     -o SOURCE: only print /dev mountpoints
#     head -n 1: print /dev mount for /
ROOT_MNT=$(findmnt -n -o SOURCE | head -n 1)

# Get USB drive serial number
#
# udevadm: get udev info
#     --name:                 dev mountpoint
#     grep SERIAL_SHORT:      get short serial number
#     awk -F"=" '{print $2}': get part after '=' sign
SERIAL=$(/bin/udevadm info --name=$ROOT_MNT | grep ID_SERIAL_SHORT | awk -F"=" '{print $2}')

# Fetch desired hostname from API
HOSTNAME=$(curl -s --retry 5 --retry-all-errors --retry-delay 1 https://hostnames.chipcie.ch.tudelft.nl/hostnames/$SERIAL/ | jq -r .hostname//empty)

# Check if we found a hostname
if [ -z "$HOSTNAME" ]
then
      echo "Could not submit hostname!"
      exit 1
fi

# Set system hostname
hostnamectl set-hostname $HOSTNAME

# Publish hostname on DNS server
IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
API_KEY=changeme
DNS_DATA='{"rrsets":[{"name":"'$HOSTNAME.local.chipcie.mawey.be.'","ttl":3600,"type":"A","changetype":"REPLACE","records":[{"content":"'$IP'","disabled":false}]}]}'
ENDPOINT=https://pdns.chipcie.ch.tudelft.nl/api/v1/servers/localhost/zones/local.chipcie.mawey.be.

curl -s --retry 5 --retry-all-errors --retry-delay 1 -H "X-API-Key: $API_KEY" -H "Content-Type: application/json"  -X PATCH  --data $DNS_DATA $ENDPOINT
