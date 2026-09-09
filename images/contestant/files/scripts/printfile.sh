#!/usr/bin/env python3

#usage: printfile North.java
#usage: printfile --output=files.ps *.java
#usage: printfile -P printer *.cpp
#usage: printfile --portrait -1 North.hs     [ For those with difficulty with the small print.]

#This script is intended for use at ACM SER 2008 ICPC; it ensures a proper header/footer:
#
#   1)  file name
#   2)  page i of n
#   3)  time of job
#   4)  Unix "user"   ("ubuntu", possibly)
#   5)  Contents of the files /ACM/SITE /ACM/TEAM
#   6)  Hostname
#   7)  Mac address
#

#  Verify /usr/bin/enscript permissions.  chmod go+rx /usr/bin/enscript
#  Verify this script's permissions.      chomd go+rx /scripts/printfile

#  This script uses "enscript" to print to the default printer (by default).  Verify
#  that a default printer has been configured; cf "lpstat -p -d"

# CUPS supports "PostScript" on all printers (where they have it or not).
# If the printer is a PostScript printer you need the PostScript Printer Description PPD
# file that comes with your printer.

import sys
import os
import subprocess
import re

sitefile = "/icpc/SITE"
roomfile = "/icpc/ROOM"
teamfile = "/icpc/TEAM"
teamidfile = "/icpc/TEAMID"
user = os.environ["USER"]

if os.path.exists(sitefile):
    site = subprocess.getoutput("cat " + sitefile)
    site = re.sub(r'[^a-zA-Z0-9_\-\s]+', '', site)
else:
    site = "[none]"

if os.path.exists(teamfile):
    team = subprocess.getoutput("cat " + teamfile)
    team = re.sub(r'[^a-zA-Z0-9_\-\s]+', '', team)
else:
    team = "[none]"

if os.path.exists(roomfile):
    room = subprocess.getoutput("cat " + roomfile)
    room = re.sub(r'[^a-zA-Z0-9_\-\s]+', '', room)
else:
    room = "[none]"

if os.path.exists(teamidfile):
    teamid = subprocess.getoutput("cat " + teamidfile)
    teamid = re.sub(r'[^a-zA-Z0-9_\-\s]+', '', teamid)
else:
    teamid = "[none]"

netDevice = subprocess.getoutput("ip route show default | awk '/default/ {print $5}'")
macAddress = subprocess.getoutput("cat /sys/class/net/" + netDevice + "/address")
hostname = subprocess.getoutput("hostname")

# Default is a4 paper
# Two columns
# Max 10 pages
# Landscape
# pretty-print ?
options = "-PPrinter0 --columns=2 --pages=-10 --landscape --pretty-print "

# The header is too wide, but footers are a pain
# header = "$n; page $% of $=; time=$C; user=$(USER); site=" + site + "; team=" + team + "; host=" + hostname + "; mac=" + macAddress
# header = "$n; page $% of $=; team=" + team + "; mac=" + macAddress
header = "'$n; page $% of $=; time=$C; room=" + room + "; team=" + team + "; teamid=" + teamid + "'"

# Though I encourage just one argument (the name of one file);
# all command line arguments are tacked on at the end

command = "/usr/bin/enscript " + options + " --header=" + header + " " + ' '.join(sys.argv[1:])
os.system(command)

# PS.  Using footers would be nice, but that would require writing enscript *.hdr files.
