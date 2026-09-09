#!/usr/bin/env bash

# Ignore SIGHUP, sometimes systemd sends it to us shortly after
# boot and that kills us.
trap '' HUP

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

WGET="wget -e use_proxy=no --timeout=5"

# whiptail redirection trick(3>&1 1>&2 2>&3) taken from:
# http://stackoverflow.com/a/1970254/841300
whiptail --title "ICPC First Time Setup" --msgbox "Please answer the following questions to finalize the configuration of your environment.\n\nYou can re-run this script later by executing '/icpc/scripts/icpc_setup.sh -f' as root." 20 60

TEAMID=$(cat /icpc/TEAMID)
TEAMID="${TEAMID:-0}"  # Set default to team
TEAMID=$(whiptail --title "Team ID" --inputbox "Please enter the team's identifier(e.g. 42)\n\nThis will be shown at the top of each printed page" 10 60 $TEAMID 3>&1 1>&2 2>&3)
/icpc/scripts/set_teamid.sh $TEAMID


TEAMNAME=$(cat /icpc/TEAM)
TEAMNAME="${TEAMNAME:-team}"  # Set default to team
TEAMNAME=$(whiptail --title "Team Name" --inputbox "Please enter the team's name(e.g. Roberts test team)\n\nThis will be shown on the team's background and at the top of each printed page" 10 60 $TEAMNAME 3>&1 1>&2 2>&3)
/icpc/scripts/set_teamname.sh $TEAMNAME

ROOM=$(cat /icpc/ROOM)
ROOM="${ROOM:-room}"  # Set default to team
ROOM=$(whiptail --title "Room" --inputbox "Please enter the team's room(e.g. TZ-2)\n\nThis will be shown at the top of each printed page" 10 60 $ROOM 3>&1 1>&2 2>&3)
/icpc/scripts/set_room.sh $ROOM

whiptail --title "Configure Automatic Login" --yesno "Do you want to configure the DOMjudge login credentials for the team?\n\nChoosing no will clear any existing login credentials." 10 60
DJAUTOLOGIN=$?
if [ $DJAUTOLOGIN -eq 0 ]; then # they click yes
  # Load existing values
  DJTEAM=$(cat /etc/squid/autologin.conf | awk '/X-DOMjudge-Login/{print $3}' | tr -d '"')
  DJPASS=$(cat /etc/squid/autologin.conf | awk '/X-DOMjudge-Pass/{print $3}' | tr -d '"' | base64 -d)
  DJTEAM="${DJTEAM:-$TEAMNAME}"  # Set default to team name if unset

  DJTEAM=$(whiptail --title "DOMjudge Login" --inputbox "Please enter the team's DOMjudge login" 10 60 $DJTEAM 3>&1 1>&2 2>&3)
  DJPASS=$(whiptail --title "DOMjudge Password" --passwordbox "Please enter the team's DOMjudge password" 10 60 $DJPASS 3>&1 1>&2 2>&3)

  /icpc/scripts/set_domjudge_creds.sh "$DJTEAM" "$DJPASS"
else
  # clear out any existing credentials
  /icpc/scripts/set_domjudge_creds.sh
fi

whiptail --title "Configure Printers" --yesno "Do you want to configure any printers at this time?\n\nNo changes will be made to the printing system if you choose no." 10 60
CONFIG_PRINTERS=$?
DO_PRINTPAGE=0
if [ $CONFIG_PRINTERS -eq 0 ]; then # they click yes
  	printerIP=$(whiptail --title "Printer Configuration" --inputbox "Please enter your printer ip address/hostname." 10 60 3>&1 1>&2 2>&3)
  	if [ -z "$printerIP" ]; then
      break;
  	else
      /icpc/scripts/set_printer.sh $printerIP
  	fi
fi

# Check if we have any printers present, if so make sure we enable the class and set it as default
# also ask about printing a test page
lpstat -v 2>/dev/null | grep Printer0 >/dev/null 2>&1
if [ $? -eq 0 ]; then
	lpadmin -d ContestPrinter
	cupsenable ContestPrinter
	accept ContestPrinter

  whiptail --title "Print Test Page?" --yesno "Would you like to send a test page to the printer?\n\n" 10 60 --defaultno
  if [ $? -eq 0 ]; then
    DO_PRINTPAGE=1
  fi
fi

# Run self test
clear
su - -c /icpc/scripts/self_test | tee /icpc/self_test_report

if [ "$DO_PRINTPAGE" -eq 1 ]; then
  su - contestant -c '/icpc/scripts/bin/printfile /icpc/self_test_report'
  echo
  echo "Test page sent to printer..."
fi
rm -f /icpc/self_test_report

read -p "Press [enter] to continue"

touch /icpc/setup_complete
