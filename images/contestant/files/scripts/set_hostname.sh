#!/usr/bin/env bash

# Get dev entry mounted as root filesystem
#
# findmnt: show mountpoints
#     -n:        don't print headers
#     -o SOURCE: only print the device column
#     /:         only match the root mountpoint
#
# Without the "/" argument this used to list every mountpoint's source
# (proc, sysfs, tmpfs, ...) and take the first line, which only happened
# to be the root device by coincidence of mount ordering - on the
# contestant VM tests' virtio-blk disk it wasn't, leaving SERIAL empty.
ROOT_MNT=$(findmnt -n -o SOURCE /)

# Get USB drive serial number
#
# udevadm: get udev info
#     --name:                 dev mountpoint
#     grep SERIAL_SHORT:      get short serial number
#     awk -F"=" '{print $2}': get part after '=' sign
SERIAL=$(/bin/udevadm info --name=$ROOT_MNT | grep ID_SERIAL_SHORT | awk -F"=" '{print $2}')

# Fetch desired hostname from API
HOSTNAME=$(curl -s --retry 5 --retry-all-errors --retry-delay 1 https://@hostnames_api@/hostnames/$SERIAL/ | jq -r .hostname//empty)

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
# TODO(WISVCH/icpc-nix#43): API_KEY is intentionally left unparameterized.
# This repo is public, so the DNS API key must not be baked in via vars.nix until proper
# secrets handling (e.g. sops-nix/agenix) is in place. See the follow-up issue.
API_KEY=changeme
DNS_DATA='{"rrsets":[{"name":"'$HOSTNAME.@dns_zone@.'","ttl":3600,"type":"A","changetype":"REPLACE","records":[{"content":"'$IP'","disabled":false}]}]}'
ENDPOINT=https://@dns_api@/api/v1/servers/localhost/zones/@dns_zone@.

curl -s --retry 5 --retry-all-errors --retry-delay 1 -H "X-API-Key: $API_KEY" -H "Content-Type: application/json"  -X PATCH  --data $DNS_DATA $ENDPOINT
