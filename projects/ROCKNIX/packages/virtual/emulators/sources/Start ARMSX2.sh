#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

source /etc/profile

DATA_ROOT="/storage/.config/ARMSX2"
mkdir -p "${DATA_ROOT}/inis"
if [ ! -f "${DATA_ROOT}/inis/PCSX2.ini" ] || \
   ! grep -q '^SettingsVersion = 1$' "${DATA_ROOT}/inis/PCSX2.ini"; then
  cp -f /usr/config/ARMSX2/inis/PCSX2.ini "${DATA_ROOT}/inis/PCSX2.ini"
fi

mkdir -p /storage/roms/bios/ps2
mkdir -p /storage/roms/savestates/ps2
mkdir -p /storage/roms/ps2/textures
sed -i '/^Textures =/c\Textures = /storage/roms/ps2/textures' "${DATA_ROOT}/inis/PCSX2.ini"
ln -sf /usr/config/SDL-GameControllerDB/gamecontrollerdb.txt "${DATA_ROOT}/game_controller_db.txt"

set_kill set "armsx2-qt"
export QT_QPA_PLATFORM=wayland
export SDL_AUDIODRIVER=pulseaudio

sway_fullscreen "armsx2-qt" &

/usr/share/armsx2-sa/armsx2-qt -datapath /storage/.config >/dev/null 2>&1
