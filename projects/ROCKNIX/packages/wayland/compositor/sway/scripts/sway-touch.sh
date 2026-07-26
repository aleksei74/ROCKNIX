#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-present ROCKNIX (https://github.com/ROCKNIX)

. /etc/profile
[ -f /run/sway/sway-daemon.conf ] && . /run/sway/sway-daemon.conf
[ -z "${SWAYSOCK}" ] && export SWAYSOCK=$(ls /run/*runtime-dir/sway-ipc.*.sock /run/sway-ipc.*.sock 2>/dev/null | head -n 1)

if [ "${DEVICE_HAS_TOUCHSCREEN}" = 'true' ]; then

# Identify touchscreen controller
TRIES=0
TOUCHSCREEN=$(swaymsg -t get_inputs 2>/dev/null | jq -r '.[] | select(.type == "touch") | .identifier' 2>/dev/null)
while [ -z "${TOUCHSCREEN}" -a $TRIES -lt 5 ]; do
	TRIES=$((TRIES+1))
	sleep 0.5
	TOUCHSCREEN=$(swaymsg -t get_inputs 2>/dev/null | jq -r '.[] | select(.type == "touch") | .identifier' 2>/dev/null)
done

if [ -n "${TOUCHSCREEN}" ]; then
	# Identify display output
	OUTPUT=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select (.focused).name' 2>/dev/null)
	[ -z "${OUTPUT}" ] && OUTPUT="DSI-1"

	# Map touchscreen
	swaymsg input "${TOUCHSCREEN}" map_to_output "${OUTPUT}" 2>/dev/null
fi

fi

