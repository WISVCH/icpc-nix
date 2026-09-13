#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [[ $# -ne 0 && $# -ne 2 ]]; then
    echo "Usage: set_domjudge_creds \"team123\" \"abc123\" or set_domjudge_creds to clear credentials"
    exit 1
fi

sed -i '/machine @domjudge_url@/d' /icpc/netrc

if [[ $# -eq 2 ]]; then
  DJTEAM=$1
  DJPASS=$2

  NETRC_STRING="machine @domjudge_url@ login $DJTEAM password $DJPASS"

  echo $NETRC_STRING >> /icpc/netrc

  #base64 encode the password to prevent any issues
  b64pass=$(echo -n "$DJPASS" | base64)

  cat > /etc/icpc/firefox-addon/config.js <<EOF
  let target = "*://@domjudge_url@/login";
  let user = "$DJTEAM";
  let password_base64 = "$b64pass";
EOF

  # sed -i "/let user = \".*\"/c\let user = \"$DJTEAM\"" /etc/icpc/firefox-addon/config.js
  # sed -i "/let password_base64 = \".*\"/c\let password_base64 = \"$b64pass\"" /etc/icpc/firefox-addon/config.js


else
  sed -i "/let user = \".*\"/c\let user = \"\"" /etc/icpc/firefox-addon/config.js
  sed -i "/let password_base64 = \".*\"/c\let password_base64 = \"\"" /etc/icpc/firefox-addon/config.js
fi

echo "Rebuilding firefox add-on, please wait a moment..."
cd /etc/icpc/firefox-addon
zip -r -FS ../dj-addon@chipcie.ch.tudelft.nl.xpi * --exclude '*.git*'
cd
pkill -f firefox-esr
rm -rf /home/*/.mozilla
