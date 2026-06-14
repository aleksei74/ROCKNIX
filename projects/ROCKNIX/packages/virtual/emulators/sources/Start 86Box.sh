#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

source /etc/profile

export QT_QPA_PLATFORM=xcb

if command -v set_kill >/dev/null 2>&1; then
  set_kill set "86box-sa"
fi

if command -v sway_fullscreen >/dev/null 2>&1; then
  sway_fullscreen "86box-sa" &
fi

/usr/bin/86box-sa -R "/storage/roms/bios/86box" >/dev/null 2>&1
