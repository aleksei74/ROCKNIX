#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

. /etc/profile

if command -v set_kill >/dev/null 2>&1; then
  set_kill set "-9 86box-sa"
fi

ROM="${1}"
PLATFORM="${2}"

# Set the cores to use
GAME=$(echo "${ROM}"| sed "s#^/.*/##")
CORES=$(get_setting "cores" "${PLATFORM}" "${GAME}")
if [ "${CORES}" = "little" ]
then
  EMUPERF="${SLOW_CORES}"
elif [ "${CORES}" = "big" ]
then
  EMUPERF="${FAST_CORES}"
else
  unset EMUPERF
fi

if [ -d "${ROM}" ]; then
  VMPATH="${ROM}"
  CFGFILE="86box.cfg"
elif [ -f "${ROM}" ]; then
  VMPATH=$(dirname "${ROM}")
  CFGFILE=$(basename "${ROM}")
else
  VMPATH="${ROM}"
  CFGFILE="86box.cfg"
fi

BIOS_PATH="/storage/roms/bios/86box"
mkdir -p "${BIOS_PATH}"

# For Qt6 on Wayland/X11
export QT_QPA_PLATFORM=xcb
case ${HW_DEVICE} in
    RK3566|RK3588|S922X)
        [[ $(/usr/bin/gpudriver) == "libmali" ]] && export QT_QPA_PLATFORM=wayland
    ;;
esac

# Run 86Box emulator
${EMUPERF} /usr/bin/86box-sa -R "${BIOS_PATH}" -P "${VMPATH}" -C "${CFGFILE}"
