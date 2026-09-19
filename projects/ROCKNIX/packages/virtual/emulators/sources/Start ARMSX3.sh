#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2023 JELOS (https://github.com/JustEnoughLinuxOS)

. /etc/profile

ARMSX3_XDG_CONFIG_HOME="/storage/.config/armsx3"
ARMSX3_XDG_CACHE_HOME="/storage/.cache/armsx3"
ARMSX3_CONFIG_ROOT="${ARMSX3_XDG_CONFIG_HOME}/rpcs3"
export XDG_CONFIG_HOME="${ARMSX3_XDG_CONFIG_HOME}"
export XDG_CACHE_HOME="${ARMSX3_XDG_CACHE_HOME}"

mkdir -p "${ARMSX3_CONFIG_ROOT}" "${ARMSX3_XDG_CACHE_HOME}"
if [ ! -f "${ARMSX3_CONFIG_ROOT}/config.yml" ] && [ -d "/usr/config/armsx3" ]; then
  cp -r "/usr/config/armsx3/." "${ARMSX3_CONFIG_ROOT}/"
fi

# Share PS3 firmware and virtual HDD data with RPCS3, but keep settings and
# JIT/shader caches separate for clean A/B testing.
FOLDER_LINKS=("dev_flash" "dev_hdd0" "dev_hdd1")
for FOLDER_LINK in "${FOLDER_LINKS[@]}"; do
  TARGET_FOLDER="/storage/roms/bios/rpcs3/$FOLDER_LINK"
  SOURCE_FOLDER="${ARMSX3_CONFIG_ROOT}/$FOLDER_LINK"

  mkdir -p "$TARGET_FOLDER"
  rm -rf "$SOURCE_FOLDER"
  ln -sf "$TARGET_FOLDER" "$SOURCE_FOLDER"
done

export QT_QPA_PLATFORM=xcb
set_kill set "-9 armsx3-sa"
sway_fullscreen "RPCS3" "class" &
/usr/bin/armsx3-sa
