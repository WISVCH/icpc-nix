#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo $1 > /icpc/TEAM

ESCAPED_NAME=`python3 - "${1}" << EOF
from gi.repository import GLib
import sys
print(GLib.markup_escape_text(" ".join(sys.argv[1:])).replace("&", "\\&"))
EOF
`

convert -background transparent -pointsize 200 -font Helvetica -fill white pango:"${ESCAPED_NAME}" -bordercolor none -border 4 -background '#000C' -alpha background -channel A -blur 4x4 -level 0,0% /icpc/teamName.png
convert /icpc/teamName.png -resize 40% /icpc/teamName.png
convert /icpc/teamName.png -resize 1800\> /icpc/teamName.png

convert -composite -gravity center /icpc/wallpaper.png /icpc/teamName.png /icpc/teamWallpaper.png
