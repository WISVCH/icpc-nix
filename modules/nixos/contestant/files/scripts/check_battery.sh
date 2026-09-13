#!/usr/bin/env bash

ac_file="/sys/class/power_supply/AC/online"
if [ ! -f "$ac_file" ]; then
    # Unknown state
    echo "UNKNOWN: AC file does not exist"
    exit 3
fi

capacity_file="/sys/class/power_supply/BAT0/capacity"
if [ ! -f "$capacity_file" ]; then
    # Unknown state
    echo "UNKNOWN: Capacity file does not exist"
    exit 3
fi

# Read values
plugged_in=$(cat /sys/class/power_supply/AC/online)
capacity=$(cat /sys/class/power_supply/BAT0/capacity)

if [ "$plugged_in" -eq 1 ]; then
    # Laptop is plugged in
    echo "BATTERY OK - $capacity% charged | charge=$capacity%;80;50;0;100"
    exit 0
elif [ "$capacity" -ge 80 ]; then
    # Laptop is not plugged in and battery level >= 80
    echo "WARNING - Battery is $capacity% charged | charge=$capacity%;80;50;0;100"
    exit 1
else
    # Laptop needs to be charged
    echo "CRITICAL - Battery is $capacity% charged | charge=$capacity%;80;50;0;100"
    exit 2
fi
