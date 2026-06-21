#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
export DISPLAY=:0
export PATH="/storage/.local/share/Steam/steam-runtime-steamrt-arm64/bin:$PATH"
export LD_LIBRARY_PATH="/storage/.local/share/Steam/lib/aarch64-linux-gnu/"
export TZ=$(cat /etc/timezone 2>/dev/null || echo "Asia/Seoul")

# Check if Steam is already running to avoid launching multiple instances
if pgrep -x "steam" > /dev/null; then
  echo "Steam is already running."
  exit 0
fi

# Start Steam in Big Picture mode (blocks until Steam exits)
/storage/.local/share/Steam/steamrtarm64/steam -bigpicture -noverifyfiles -nobootstrapupdate -skipinitialbootstrap -norepairfiles -noshaders "$@"

# Once Steam exits, automatically return to gaming mode
if [ -f "/usr/bin/return-to-gaming-mode.sh" ]; then
  exec /usr/bin/return-to-gaming-mode.sh
else
  exec /storage/bin/return-to-gaming-mode.sh
fi
