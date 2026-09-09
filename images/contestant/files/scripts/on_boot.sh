#!/usr/bin/env bash

# Ignore SIGHUP, sometimes systemd sends it to us shortly after
# boot and that kills us.
trap '' HUP

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

cat << EOF
 _____  _   _ _       _____ _             _   _ _      
/  __ \| | | (_)     /  __ (_)           | \ | (_)     
| /  \/| |_| |_ _ __ | /  \/_  ___ ______|  \| |___  __
| |    |  _  | | '_ \| |   | |/ _ \______| . ' | \ \/ /
| \__/\| | | | | |_) | \__/\ |  __/      | |\  | |>  < 
 \____/\_| |_/_| .__/ \____/_|\___|      \_| \_/_/_/\_\ 
               | |                                     
               |_|                                     

EOF

# su - -c /icpc/scripts/set_hostname.sh
{
/run/current-system/sw/bin/su - -c /etc/icpc/scripts/self_test
} || {
echo "Self test failed, please check the logs"
}
# if [ -f /icpc/setup_complete ]; then
#   # nothing to do, setup is already done(but still let it run with -f or --force)
#   echo "Already configured."
#   exit
# fi

read -r -p "Do you want to run icpc_setup? [y/N] " response
response=${response,,}    # tolower
if [[ "$response" =~ ^(yes|y)$ ]]
then
    /etc/icpc/scripts/icpc_setup.sh
fi
