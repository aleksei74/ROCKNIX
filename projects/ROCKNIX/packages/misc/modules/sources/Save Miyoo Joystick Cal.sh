#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025 ROCKNIX (https://github.com/ROCKNIX)

. /etc/profile

SYSFS_DIR="/sys/devices/platform/rocknix-singleadc-joypad"
CAL_DIR="/storage/.config/miyoo-serial-joypad"

# Red foreground (works on Linux console and most terminals)
R=$'\033[31m'
N=$'\033[0m'

show_logo() {
  echo "${R}"
  echo "███╗   ███╗██╗██╗   ██╗ ██████╗  ██████╗     ███████╗██╗     ██╗██████╗ "
  echo "████╗ ████║██║╚██╗ ██╔╝██╔═══██╗██╔═══██╗    ██╔════╝██║     ██║██╔══██╗"
  echo "██╔████╔██║██║ ╚████╔╝ ██║   ██║██║   ██║    █████╗  ██║     ██║██████╔╝"
  echo "██║╚██╔╝██║██║  ╚██╔╝  ██║   ██║██║   ██║    ██╔══╝  ██║     ██║██╔═══╝ "
  echo "██║ ╚═╝ ██║██║   ██║   ╚██████╔╝╚██████╔╝    ██║     ███████╗██║██║     "
  echo "╚═╝     ╚═╝╚═╝   ╚═╝    ╚═════╝  ╚═════╝     ╚═╝     ╚══════╝╚═╝╚═╝     "
  echo "${N}"
}

exit_after_delay() {
  echo ""
  echo "${R}Exiting in 5 seconds...${N}"
  sleep 5
}

clear
show_logo

if [ ! -f "${SYSFS_DIR}/miyoo_cal_left" ]; then
  echo "${R}This tool is only for the Miyoo Flip.${N}"
  echo "${R}This device does not use the Miyoo serial joypad driver.${N}"
  exit_after_delay
  exit 0
fi

echo "${R}Joystick Calibration${N}"
echo ""
echo "${R}The joysticks auto-calibrate during use.${N}"
echo "${R}This tool saves the current values so${N}"
echo "${R}they persist across reboots.${N}"
echo ""
echo "${R}To reset: delete the folder${N}"
echo "${R}  ${CAL_DIR}${N}"
echo "${R}and restart the device.${N}"
echo ""

mkdir -p "${CAL_DIR}"

for stick in left right; do
  sysfs="${SYSFS_DIR}/miyoo_cal_${stick}"
  if [ -f "${sysfs}" ]; then
    cat "${sysfs}" > "${CAL_DIR}/cal_${stick}"
    echo "${R}Saved ${stick} stick: $(cat "${sysfs}")${N}"
  fi
done

for param in expand_margin expand_hits; do
  sysfs="${SYSFS_DIR}/miyoo_${param}"
  if [ -f "${sysfs}" ]; then
    cat "${sysfs}" > "${CAL_DIR}/${param}"
  fi
done

echo ""
echo "${R}Calibration saved to ${CAL_DIR}${N}"
exit_after_delay
