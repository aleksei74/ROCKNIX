#!/bin/bash

# 1. Restore kiosk configuration
mkdir -p /storage/.config/sway
cp /usr/share/sway/config.kiosk /storage/.config/sway/config

# 2. Unmask and reload essway
systemctl unmask essway.service
systemctl daemon-reload

# 3. Start essway.service (which starts ES)
systemctl start essway.service

# 4. Exit sway session
swaymsg exit
