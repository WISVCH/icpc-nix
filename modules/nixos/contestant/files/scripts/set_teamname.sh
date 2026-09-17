#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo $1 > /icpc/TEAM

ESCAPED_NAME=`escape-markup "${1}"`

# `magick`, not `convert`: ImageMagick 7 warns on every `convert` call
# ("the convert command is deprecated in IMv7") and drops the alias
# entirely in 8, so this breaks outright on a future nixpkgs bump.
magick -background transparent -pointsize 200 -font Helvetica -fill white pango:"${ESCAPED_NAME}" -bordercolor none -border 4 -background '#000C' -alpha background -channel A -blur 4x4 -level 0,0% /icpc/teamName.png
magick /icpc/teamName.png -resize 40% /icpc/teamName.png
magick /icpc/teamName.png -resize 1800\> /icpc/teamName.png

# Images first, then -gravity, then -composite: `-composite` is an operator,
# so under `magick` it needs both images already on the stack, where the
# legacy `convert` parser accepted it as the first argument. Same result -
# first image is the destination, second the centred overlay.
magick /icpc/wallpaper.png /icpc/teamName.png -gravity center -composite /icpc/teamWallpaper.png
