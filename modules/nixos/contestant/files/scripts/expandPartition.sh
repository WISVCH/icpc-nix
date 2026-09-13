#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]
  then echo "Script should be run as root"
  exit
fi

part=$1
disk=$(lsblk -ndo pkname $part)

growpart /dev/$disk $(echo -n $part | tail -c 1)
resize2fs $part
