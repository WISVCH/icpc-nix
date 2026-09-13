#!/usr/bin/env python3

import sys
import pathlib
from fpdf import FPDF
import tempfile
import subprocess
import re
from PyPDF2 import PdfMerger
import os
import shutil


assert len(sys.argv) == 4

file_path = pathlib.Path(sys.argv[1])


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


with tempfile.NamedTemporaryFile() as tmp1, tempfile.NamedTemporaryFile() as tmp2:
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Arial", size = 25)

    pdf.cell(200, 10, txt = f"Team: {team}", ln = 1, align = 'C')
    pdf.cell(200, 10, txt = f"Id: {teamid}", ln = 1, align = 'C')
    pdf.cell(200, 10, txt = f"Room: {room}", ln = 1, align = 'C')

    pdf.output(tmp1.name)

    merger = PdfMerger()
    merger.append(tmp1.name)
    merger.append(file_path)

    merger.write(tmp2.name)
    merger.close()

    subprocess.run(["lp", "-d", "Printer0", "-t", f"\"CHipCie by Team {team}\"", tmp2.name])
