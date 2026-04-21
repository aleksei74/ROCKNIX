#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

source /etc/profile
set_kill set "-9 steam"

mkdir -p /storage/roms/steam/steamapps
VDF="/storage/.local/share/Steam/steamapps/libraryfolders.vdf"
if [  -f $VDF ]; then
    grep -q '"/storage/roms/steam"' "$VDF" || sed -i '$ s/}/\t"1" {"path" "\/storage\/roms\/steam"}\n}/' "$VDF"
fi

#Emulation Station Features
GAME=$(echo "${1}"| sed "s#^/.*/##")
PLATFORM=$(echo "${2}"| sed "s#^/.*/##")
GAMESCOPE=$(get_setting gamescope "${PLATFORM}" "${GAME}")

#Set the cores to use
CORES=$(get_setting "cores" "${PLATFORM}" "${GAME}")
if [ "${CORES}" = "little" ]
then
  EMUPERF="${SLOW_CORES}"
elif [ "${CORES}" = "big" ]
then
  EMUPERF="${FAST_CORES}"
else
  ### All..
  unset EMUPERF
fi

# Debugging info:
  echo "GAME set to: ${GAME}"
  echo "PLATFORM set to: ${PLATFORM}"
  echo "CPU CORES set to: ${EMUPERF}"
  echo "GAMESCOPE set to: ${GAMESCOPE}"

systemctl stop systemd-binfmt
mkdir -p "/storage/.local/share/Steam/steamapps/common/Proton 11.0 (ARM64)/"
cp -f "/storage/toolmanifest.vdf" "/storage/.local/share/Steam/steamapps/common/Proton 11.0 (ARM64)/"

if [ "${DEVICE_HAS_DUAL_SCREEN}" = "true" ]; then
  swaymsg 'seat seat1 fallback true'
fi
if [[ "$1" == *.desktop && -f "$1" && "$(basename "$1")" != "Steam.desktop" ]]; then
    EXEC_LINE=$(grep -m1 '^Exec=' "$1" | cut -d'=' -f2-)
    GAME_URI="${EXEC_LINE#steam }"
    if [ "${GAMESCOPE}" = "0" ]; then
        SDL_VIDEODRIVER=x11 LD_LIBRARY_PATH=/storage/.local/share/Steam/lib/aarch64-linux-gnu/ ${EMUPERF} /storage/.local/share/Steam/steamrtarm64/steam -bigpicture "$GAME_URI"
    else
        LD_LIBRARY_PATH=/storage/.local/share/Steam/lib/aarch64-linux-gnu/ ${EMUPERF} gamescope -w 1920 -h 1080 -e -- /storage/.local/share/Steam/steamrtarm64/steam -bigpicture "$GAME_URI"
    fi
else
    if [ "${GAMESCOPE}" = "0" ]; then
        SDL_VIDEODRIVER=x11 LD_LIBRARY_PATH=/storage/.local/share/Steam/lib/aarch64-linux-gnu/ ${EMUPERF} /storage/.local/share/Steam/steamrtarm64/steam -bigpicture
    else
        LD_LIBRARY_PATH=/storage/.local/share/Steam/lib/aarch64-linux-gnu/ ${EMUPERF} gamescope -w 1920 -h 1080 -e -- /storage/.local/share/Steam/steamrtarm64/steam -bigpicture
    fi
fi
if [ "${DEVICE_HAS_DUAL_SCREEN}" = "true" ]; then
  swaymsg 'seat seat1 fallback false'
fi
systemctl start systemd-binfmt
