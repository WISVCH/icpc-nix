#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [[ $# -ne 0 && $# -ne 2 ]]; then
    echo "Usage: set_domjudge_creds \"team123\" \"abc123\" or set_domjudge_creds to clear credentials"
    exit 1
fi

sed -i '/machine dj.chipcie.ch.tudelft.nl/d' /icpc/netrc

if [[ $# -eq 2 ]]; then
  DJTEAM=$1
  DJPASS=$2

  NETRC_STRING="machine {{ domjudge_url }} login $DJTEAM password $DJPASS"

  echo $NETRC_STRING >> /icpc/netrc

  #base64 encode the password to prevent any issues
  b64pass=$(echo -n "$DJPASS" | base64)

  mkdir -p /etc/squid
  cat > /etc/squid/autologin.conf <<EOF
request_header_add X-DOMjudge-Autologin true autologin
request_header_add X-DOMjudge-Login "$DJTEAM" autologin
request_header_add X-DOMjudge-Pass "$b64pass" autologin
EOF

  cat > /etc/icpc/firefox-addon/config.js <<EOF
  let target = "*://dj.chipcie.ch.tudelft.nl/login";
  let user = "$DJTEAM";
  let password_base64 = "$b64pass";
EOF

  # sed -i "/let user = \".*\"/c\let user = \"$DJTEAM\"" /etc/icpc/firefox-addon/config.js
  # sed -i "/let password_base64 = \".*\"/c\let password_base64 = \"$b64pass\"" /etc/icpc/firefox-addon/config.js


else
  echo "#placeholder" > /etc/squid/autologin.conf

  sed -i "/let user = \".*\"/c\let user = \"\"" /etc/icpc/firefox-addon/config.js
  sed -i "/let password_base64 = \".*\"/c\let password_base64 = \"\"" /etc/icpc/firefox-addon/config.js
fi

echo "Rebuilding firefox add-on, please wait a moment..."
cd /etc/icpc/firefox-addon
zip -r -FS ../dj-addon@chipcie.ch.tudelft.nl.xpi * --exclude '*.git*'
cd
pkill -f firefox-esr
rm -rf /home/*/.mozilla

echo "Reconfiguring squid, please wait a moment..."
# make sure the contestant user can't read the credentials
chmod 640 /etc/squid/autologin.conf
chown squid:squid /etc/squid/autologin.conf

# restart squid to pick up on the changes(start then stop in case squid isn't running)
systemctl restart squid
