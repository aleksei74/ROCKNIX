#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

. /etc/profile

DATA_ROOT="/storage/.config/armsx2"
if [ ! -f "${DATA_ROOT}/ARMSX2.ini" ]; then
  mkdir -p "${DATA_ROOT}"
  cp -rf /usr/config/armsx2/. "${DATA_ROOT}/"
fi
mkdir -p /storage/roms/bios/armsx2
mkdir -p /storage/roms/savestates/ps2

# Use Rocknix's curated SDL controller DB so device-specific mappings (e.g.
# "Retroid Pocket Gamepad" on Linux) override the upstream-only bundle ARMSX2
# ships in resources/. SDLInputSource looks in DataRoot first.
ln -sf /usr/config/SDL-GameControllerDB/gamecontrollerdb.txt "${DATA_ROOT}/game_controller_db.txt"

# The Rocknix mapping for the RP5 swaps face buttons Nintendo-style so that
# SDL_SOUTH fires on the labeled-A button (east physical position). PCSX2's
# FullscreenUI menu draws the Sony Cross glyph for activate and expects it
# on SDL_SOUTH, so this Nintendo flip makes the on-screen prompt fire on
# the wrong physical button. Override with a position-correct mapping so
# that pressing the south-physical button (labeled B on the RP5) activates,
# matching the Cross glyph's positional meaning.
export SDL_GAMECONTROLLERCONFIG="0300f353202000000130000001000000,Retroid Pocket Gamepad,platform:Linux,a:b0,b:b1,x:b3,y:b2,back:b6,guide:b8,start:b7,dpleft:b13,dpdown:b12,dpright:b14,dpup:b11,leftshoulder:b4,lefttrigger:a6,rightshoulder:b5,righttrigger:a7,leftstick:b9,rightstick:b10,leftx:a0,lefty:a1,rightx:a3,righty:a4,misc1:b15,"

# Mesa freedreno-classic-GL on Adreno 650 (Snapdragon 865 / RP5) renders
# long-lived RGBA8 textures as RGB hash noise after the first upload, while
# re-uploaded-each-frame textures are correct. Bisected to the GL backend:
# software GS is clean, dumped textures on disk are byte-perfect, and Turnip
# (Mesa Vulkan freedreno) renders correctly. Route GL through Zink so calls
# reach Turnip via Vulkan instead of the broken classic-GL path. Falls back
# silently to the default driver on devices without zink_dri.so.
export MESA_LOADER_DRIVER_OVERRIDE=zink

GAME=$(echo "${1}" | sed "s#^/.*/##")
PLATFORM=$(echo "${2}" | sed "s#^/.*/##")
CORES=$(get_setting "cores" "${PLATFORM}" "${GAME}")
if [ "${CORES}" = "little" ]; then
  EMUPERF="${SLOW_CORES}"
elif [ "${CORES}" = "big" ]; then
  EMUPERF="${FAST_CORES}"
else
  unset EMUPERF
fi

set_kill set "-9 armsx2"
${EMUPERF} /usr/bin/armsx2 \
  --app-root /usr/share/armsx2/assets \
  --data-root "${DATA_ROOT}" \
  "${1}"
