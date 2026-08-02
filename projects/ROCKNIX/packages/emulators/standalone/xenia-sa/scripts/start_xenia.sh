#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

. /etc/profile
set_kill set "-9 xenia_canary"

CONF_DIR="/storage/.config/xenia"
CONTENT_DIR="${CONF_DIR}/content"
CACHE_DIR="${CONF_DIR}/cache"

mkdir -p "${CONF_DIR}" "${CONTENT_DIR}" "${CACHE_DIR}"

# Xenia's Linux frontend currently uses GTK/X11 and an XCB Vulkan surface.
export DISPLAY="${DISPLAY:-:0}"
export GDK_BACKEND="x11"
export SDL_VIDEODRIVER="x11"

sway_fullscreen "xenia" &

ARGS=(
  "--gpu=vulkan"
  "--apu=alsa"
  "--hid=sdl"
  "--fullscreen=true"
  "--storage_root=${CONF_DIR}"
  "--content_root=${CONTENT_DIR}"
  "--cache_root=${CACHE_DIR}"
)

if [ -n "$1" ]; then
  ARGS+=("$1")
fi

/usr/bin/xenia_canary "${ARGS[@]}"
