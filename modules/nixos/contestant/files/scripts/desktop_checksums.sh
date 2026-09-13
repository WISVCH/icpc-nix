#!/usr/bin/env bash

for f in ~/Desktop/*.desktop
do
   if ! gio info "$f" | grep metadata::xfce-exe-checksum > /dev/null 2>&1; then
      chmod +x "$f"
      gio set -t string "$f" metadata::xfce-exe-checksum "$(sha256sum "$f" | awk '{print $1}')"
   fi
done
exit 0
