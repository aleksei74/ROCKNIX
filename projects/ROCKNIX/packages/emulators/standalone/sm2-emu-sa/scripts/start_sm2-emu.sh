#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
. /etc/profile
set_kill set "-9 sm2-emu"

ROM="$1"
if [ ! -f "${ROM}" ]; then
  echo "sm2-emu: ROM not found: ${ROM}" >&2
  exit 1
fi

GAME="$(basename "${ROM}")"
PLATFORM="$(basename "${2:-segamodel2}")"
CONFIG_DIR="/storage/.config/sm2-emu"
mkdir -p "${CONFIG_DIR}"

if [ -r /usr/share/turnip/turnip-env.sh ]; then
  . /usr/share/turnip/turnip-env.sh
  rocknix_turnip_apply sm2-emu "$(get_setting turnip_driver "${PLATFORM}" "${GAME}")"
fi

export SDL_VIDEODRIVER=wayland

CORES="$(get_setting cores "${PLATFORM}" "${GAME}")"
case "${CORES}" in
  little) EMUPERF="${SLOW_CORES}" ;;
  big) EMUPERF="${FAST_CORES}" ;;
  *) unset EMUPERF ;;
esac

OPTIONS=(--config "${CONFIG_DIR}" --fullscreen)

BACKEND="$(get_setting graphics_backend "${PLATFORM}" "${GAME}")"
case "${BACKEND}" in
  vulkan|opengl) OPTIONS+=(--graphics-backend "${BACKEND}") ;;
  *) OPTIONS+=(--graphics-backend software) ;;
esac

SCALE="$(get_setting render_scale "${PLATFORM}" "${GAME}")"
case "${SCALE}" in
  1|2|3|4) OPTIONS+=(--render-scale "${SCALE}") ;;
esac

if [ "$(get_setting vsync "${PLATFORM}" "${GAME}")" = "false" ]; then
  OPTIONS+=(--no-vsync)
fi

sway_fullscreen sm2-emu &
echo "Command: sm2-emu ${OPTIONS[*]} ${ROM}" >/var/log/exec.log
${EMUPERF} /usr/bin/sm2-emu "${OPTIONS[@]}" "${ROM}" >>/var/log/exec.log 2>&1
