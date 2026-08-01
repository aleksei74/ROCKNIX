#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

. /etc/profile

DATA_ROOT="/storage/.config/ARMSX2"
mkdir -p "${DATA_ROOT}/inis"

if [ ! -f "${DATA_ROOT}/inis/PCSX2.ini" ]; then
    cp -r /usr/config/ARMSX2/inis/PCSX2.ini "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ ! -f "${DATA_ROOT}/inis/secrets.ini" ]; then
    cp -r /usr/config/ARMSX2/inis/secrets.ini "${DATA_ROOT}/inis/secrets.ini"
fi

mkdir -p /storage/roms/bios/ps2
mkdir -p /storage/roms/savestates/ps2
mkdir -p /storage/roms/ps2/textures
sed -i '/^Textures =/c\Textures = /storage/roms/ps2/textures' "${DATA_ROOT}/inis/PCSX2.ini"

# Use Rocknix's curated SDL controller DB
ln -sf /usr/config/SDL-GameControllerDB/gamecontrollerdb.txt "${DATA_ROOT}/game_controller_db.txt" 2>/dev/null

# EmulationStation Features
GAME=$(echo "${1}" | sed "s#^/.*/##")
PLATFORM=$(echo "${2}" | sed "s#^/.*/##")
ASPECT=$(get_setting aspect_ratio "${PLATFORM}" "${GAME}")
FILTER=$(get_setting bilinear_filtering "${PLATFORM}" "${GAME}")
FPS=$(get_setting show_fps "${PLATFORM}" "${GAME}")
RATE=$(get_setting ee_cycle_rate "${PLATFORM}" "${GAME}")
SKIP=$(get_setting ee_cycle_skip "${PLATFORM}" "${GAME}")
HWDOWNLOAD=$(get_setting hw_download_mode "${PLATFORM}" "${GAME}")
GRENDERER=$(get_setting graphics_backend "${PLATFORM}" "${GAME}")
IRES=$(get_setting internal_resolution "${PLATFORM}" "${GAME}")
VSYNC=$(get_setting vsync "${PLATFORM}" "${GAME}")
ENABLE_WIDESCREEN_PATCHES=$(get_setting enable_widescreen_patches "${PLATFORM}" "${GAME}")

CORES=$(get_setting "cores" "${PLATFORM}" "${GAME}")
if [ "${CORES}" = "little" ]; then
  EMUPERF="${SLOW_CORES}"
elif [ "${CORES}" = "big" ]; then
  EMUPERF="${FAST_CORES}"
else
  unset EMUPERF
fi

if [ "$ASPECT" = "0" ]; then
  sed -i '/^AspectRatio =/c\AspectRatio = 4:3' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$ASPECT" = "1" ]; then
  sed -i '/^AspectRatio =/c\AspectRatio = 16:9' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$ASPECT" = "2" ]; then
  sed -i '/^AspectRatio =/c\AspectRatio = Stretch' "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ "$FILTER" = "0" ]; then
  sed -i '/^filter =/c\filter = 0' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$FILTER" = "1" ]; then
  sed -i '/^filter =/c\filter = 1' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$FILTER" = "2" ]; then
  sed -i '/^filter =/c\filter = 2' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$FILTER" = "3" ]; then
  sed -i '/^filter =/c\filter = 3' "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ "$GRENDERER" = "0" ]; then
  sed -i '/^Renderer =/c\Renderer = -1' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$GRENDERER" = "1" ]; then
  sed -i '/^Renderer =/c\Renderer = 12' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$GRENDERER" = "2" ]; then
  sed -i '/^Renderer =/c\Renderer = 14' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$GRENDERER" = "3" ]; then
  sed -i '/^Renderer =/c\Renderer = 13' "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ "$IRES" > "0" ]; then
  sed -i "/^upscale_multiplier =/c\upscale_multiplier = $IRES" "${DATA_ROOT}/inis/PCSX2.ini"
else
  sed -i '/^upscale_multiplier =/c\upscale_multiplier = 1' "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ "$FPS" = "false" ]; then
  sed -i '/^OsdShowFPS =/c\OsdShowFPS = false' "${DATA_ROOT}/inis/PCSX2.ini"
elif [ "$FPS" = "true" ]; then
  sed -i '/^OsdShowFPS =/c\OsdShowFPS = true' "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ "$ENABLE_WIDESCREEN_PATCHES" = "true" ]; then
  sed -i '/^EnableWideScreenPatches =/c\EnableWideScreenPatches = true' "${DATA_ROOT}/inis/PCSX2.ini"
else
  sed -i '/^EnableWideScreenPatches =/c\EnableWideScreenPatches = false' "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ -f /usr/bin/cheevos_armsx2.sh ]; then
  /usr/bin/cheevos_armsx2.sh
fi

@GRAPHICS@

export QT_QPA_PLATFORM=wayland
export SDL_AUDIODRIVER=pulseaudio

set_kill set "-9 armsx2-qt"
${EMUPERF} /usr/share/armsx2-sa/armsx2-qt \
  -bigpicture \
  -fullscreen \
  -datapath /storage/.config \
  -- "${1}"
