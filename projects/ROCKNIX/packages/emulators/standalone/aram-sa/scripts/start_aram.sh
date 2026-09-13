#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 ROCKNIX

source /etc/profile

ROM="$1"

if [ -z "${ROM}" ] || [ ! -f "${ROM}" ]; then
  echo "ARAM: ROM package not found: ${ROM}" >&2
  exit 2
fi

set_kill set "aram"
sway_fullscreen "ARAM" &

export ARAM_CPU="fastest"
exec /usr/bin/aram "${ROM}"
