#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
. /etc/profile
set_kill set "-9 hakux-sa"

if [ ! -f "$1" ]; then
  echo "hakuX: Xbox game image not found: $1" >&2
  exit 1
fi

GAME="$(basename "$1")"
PLATFORM="$(basename "${2:-xbox}")"
HDD="/storage/.config/hakux/hdd"
mkdir -p "$HDD"

if [ -r /usr/share/turnip/turnip-env.sh ]; then
  . /usr/share/turnip/turnip-env.sh
  rocknix_turnip_apply hakux "$(get_setting turnip_driver "$PLATFORM" "$GAME")"
fi

export SDL_VIDEODRIVER=wayland
export HAKUX_NATIVE_BASE=/storage/.cache/hakux
mkdir -p "$HAKUX_NATIVE_BASE"

exec /usr/bin/hakux-sa "$1" "$HDD"
