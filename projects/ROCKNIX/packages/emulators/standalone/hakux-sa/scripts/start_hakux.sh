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

HAKUX_ARGS=()
VALUE="$(get_setting hakux_render_scale "$PLATFORM" "$GAME")"
case "$VALUE" in
  1|2|3|4) HAKUX_ARGS+=("scale=$VALUE") ;;
esac

VALUE="$(get_setting hakux_aspect_ratio "$PLATFORM" "$GAME")"
case "$VALUE" in
  4:3|16:9|stretch) HAKUX_ARGS+=("aspect=$VALUE") ;;
esac

VALUE="$(get_setting hakux_fxaa "$PLATFORM" "$GAME")"
case "$VALUE" in
  0|1) HAKUX_ARGS+=("fxaa=$VALUE") ;;
esac

VALUE="$(get_setting hakux_upscaling "$PLATFORM" "$GAME")"
case "$VALUE" in
  bilinear|sgsr) HAKUX_ARGS+=("upscale=$VALUE") ;;
esac

VALUE="$(get_setting hakux_asynchronous_shaders "$PLATFORM" "$GAME")"
case "$VALUE" in
  0|1) HAKUX_ARGS+=("asyncpipe=$VALUE") ;;
esac

VALUE="$(get_setting hakux_shader_prebuild "$PLATFORM" "$GAME")"
case "$VALUE" in
  0|1) HAKUX_ARGS+=("prebuild=$VALUE") ;;
esac

exec /usr/bin/hakux-sa "$1" "$HDD" "${HAKUX_ARGS[@]}"
