#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025 ROCKNIX (https://github.com/ROCKNIX)

. /etc/profile

SYSFS_DIR="/sys/devices/platform/rocknix-singleadc-joypad"
CAL_DIR="/storage/.config/miyoo-serial-joypad"

# Red only for ASCII logo
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
  echo "Exiting in 5 seconds..."
  sleep 5
}

clear
show_logo

if [ ! -f "${SYSFS_DIR}/miyoo_cal_left" ]; then
  echo "This tool is only for the Miyoo Flip."
  echo "This device does not use the Miyoo serial joypad driver."
  exit_after_delay
  exit 0
fi

echo "Miyoo autocalibration save"
echo ""
echo "Sticks auto-calibrate during use. This saves current values"
echo "so they persist across reboots."
echo ""
echo "To reset: delete the folder"
echo "  ${CAL_DIR}"
echo "and restart the device."
echo ""

mkdir -p "${CAL_DIR}"

for stick in left right; do
  sysfs="${SYSFS_DIR}/miyoo_cal_${stick}"
  if [ -f "${sysfs}" ]; then
    cat "${sysfs}" > "${CAL_DIR}/cal_${stick}"
    echo "Saved ${stick} stick: $(cat "${sysfs}")"
  fi
done

for param in expand_margin expand_hits; do
  sysfs="${SYSFS_DIR}/miyoo_${param}"
  if [ -f "${sysfs}" ]; then
    cat "${sysfs}" > "${CAL_DIR}/${param}"
  fi
done

echo ""
echo "Calibration saved to ${CAL_DIR}"
exit_after_delay
