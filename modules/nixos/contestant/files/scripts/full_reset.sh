#!/usr/bin/env bash

# Remove the team wallpaper
rm -f /icpc/teamWallpaper.png

# Delete the printers/printer class
for PRINTER in $(lpstat -v | cut -d ' ' -f 3 | tr -d ':')
do
  lpadmin -x $PRINTER
done
lpadmin -x ContestPrinter

# clear the user
/icpc/scripts/deleteUser.sh

rm -f /icpc/setup_complete
rm -f /icpc/TEAM
rm -f /icpc/TEAMID
rm -f /icpc/ROOM

# clear the previous team's DOMjudge credentials
> /icpc/netrc

# clear self test report
rm -f /icpc/self_test_report
