#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

. /etc/profile
set_kill set "-9 sdoj-recomp"

# Load gptokeyb support files
control-gen_init.sh
source /storage/.config/gptokeyb/control.ini
get_controls

CONF_DIR="/storage/.config/sdoj-recomp"
ROMS_DIR="/storage/roms/ports/sdoj"

mkdir -p "${CONF_DIR}"
mkdir -p "${CONF_DIR}/cache"
mkdir -p "${ROMS_DIR}"

# Determine game data root directory
GAME_DATA="${ROMS_DIR}"
if [ -n "$1" ] && [ -d "$1" ]; then
  GAME_DATA="$1"
elif [ -n "$1" ] && [ -f "$1" ]; then
  GAME_DATA="$(dirname "$1")"
fi

cd "${GAME_DATA}"

# Build CLI arguments for ReXGlue / SDOJ Recomp
ARGS=("--game_data_root=${GAME_DATA}" "--user_data_root=${CONF_DIR}" "--cache_path=${CONF_DIR}/cache" "--vulkan_readback_resolve=false" "--vulkan_readback_memexport=false" "--vulkan_async_skip_incomplete_frames=false" "--vsync=false" "--render_target_path_vulkan=fbo" "--fullscreen")

# Auto-detect Title Update (TU) directory if present
if [ -d "${GAME_DATA}/tu" ]; then
  ARGS+=("--update_data_root=${GAME_DATA}/tu")
elif [ -d "${GAME_DATA}/TU" ]; then
  ARGS+=("--update_data_root=${GAME_DATA}/TU")
elif [ -d "${GAME_DATA}/tu1" ]; then
  ARGS+=("--update_data_root=${GAME_DATA}/TU1")
elif [ -d "${GAME_DATA}/TU1" ]; then
  ARGS+=("--update_data_root=${GAME_DATA}/TU1")
elif [ -d "${ROMS_DIR}/tu" ]; then
  ARGS+=("--update_data_root=${ROMS_DIR}/tu")
elif [ -d "${ROMS_DIR}/TU1" ]; then
  ARGS+=("--update_data_root=${ROMS_DIR}/TU1")
fi

# Determine which binary to run
if [ -x "${GAME_DATA}/sdoj-recomp" ]; then
  SDOJ_BIN="${GAME_DATA}/sdoj-recomp"
elif [ -x "${GAME_DATA}/saidaioujou_recomp_tu1" ]; then
  SDOJ_BIN="${GAME_DATA}/saidaioujou_recomp_tu1"
elif [ -x "${ROMS_DIR}/sdoj-recomp" ]; then
  SDOJ_BIN="${ROMS_DIR}/sdoj-recomp"
else
  echo "SDOJ executable not found in ${GAME_DATA} or ${ROMS_DIR}" >&2
  exit 1
fi

# Launch gptokeyb mapping if available
if [ -f "${CONF_DIR}/sdoj.gptk" ]; then
  ${GPTOKEYB} sdoj-recomp -c "${CONF_DIR}/sdoj.gptk" &
elif [ -f "${ROMS_DIR}/sdoj.gptk" ]; then
  ${GPTOKEYB} sdoj-recomp -c "${ROMS_DIR}/sdoj.gptk" &
fi

export LD_LIBRARY_PATH="${GAME_DATA}:${ROMS_DIR}:/usr/lib:${LD_LIBRARY_PATH}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export DISPLAY="${DISPLAY:-:0}"
# ReXGlue currently exposes only the XCB Vulkan surface on GNU/Linux. Keep SDL
# on XWayland until its presenter supports creating native Wayland surfaces.
export SDL_VIDEODRIVER="x11"
export GDK_BACKEND="x11"

if [ -S "/var/run/0-runtime-dir/sway-ipc.0.sock" ]; then
  export SWAYSOCK="/var/run/0-runtime-dir/sway-ipc.0.sock"
fi

(
  # The binary may expose either an SDL app_id or an XWayland class depending
  # on the selected video backend. Retry while the window is being created.
  for _attempt in {1..20}; do
    sleep 0.25
    if command -v swaymsg &>/dev/null && swaymsg -q get_tree &>/dev/null 2>&1; then
      for _criteria in \
        '[app_id="(?i)^(sdoj-recomp|saidaioujou_recomp_tu1)$"]' \
        '[class="(?i)^(sdoj-recomp|saidaioujou_recomp_tu1)$"]'; do
        swaymsg "${_criteria} focus" 2>/dev/null
        swaymsg "${_criteria} fullscreen enable" 2>/dev/null
      done
    fi

    if swaymsg -t get_tree -r 2>/dev/null | grep -Eqi \
      '"(app_id|class)"[[:space:]]*:[[:space:]]*"(sdoj-recomp|saidaioujou_recomp_tu1)"'; then
      break
    fi
  done
) &

"${SDOJ_BIN}" "${ARGS[@]}"

kill -9 $(pidof gptokeyb) 2>/dev/null
