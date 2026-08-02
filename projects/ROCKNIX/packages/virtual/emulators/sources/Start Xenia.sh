#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

source /etc/profile

set_kill set "-9 xenia_canary"

/usr/bin/start_xenia.sh >/dev/null 2>&1
