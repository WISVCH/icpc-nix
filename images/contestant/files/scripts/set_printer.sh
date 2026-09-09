#!/usr/bin/env bash
printerIP=$1

if [[ ! $printerIP =~ ":/" ]]; then
  printerIP="socket://$printerIP"
fi

# Purge all PDF queues and disable them.
for queue in $(LC_ALL=C lpstat -h localhost -v 2>/dev/null | grep 'cups-pdf:/' | cut -d ':' -f 1 | cut -d ' ' -f 3)
do
  cupsreject -h localhost $queue 2>/dev/null
  cupsdisable -h localhost $queue 2>/dev/null
  lpadmin -h localhost -x $queue 2>/dev/null
done

# Clear out all old printers
for PRINTER in $(lpstat -v 2>/dev/null| cut -d ' ' -f 3 | tr -d ':')
do
  lpadmin -x $PRINTER
done

# Add real printer
lpadmin -p Printer0 -v $printerIP -E
cupsenable Printer0
cupsaccept Printer0

# Add PDF printer
size="$(LC_ALL=C paperconf 2>/dev/null)" || size=a4
lpadmin -h localhost -p ContestPrinter -v cups-pdf:/ -m lsb/usr/cups-pdf/CUPS-PDF_opt.ppd -o pdftops-renderer-default=pdftocairo -o printer-is-shared=no -o PageSize=$size 2>/dev/null
cupsenable -h localhost ContestPrinter
cupsaccept -h localhost ContestPrinter

# Set ContestPrinter as default
lpadmin -d ContestPrinter
