#!/bin/sh

. /etc/profile

ROM="${1}"
PROFILE_DIR="/storage/.config/Ymir"
DEFAULT_CONFIG="/usr/config/Ymir/Ymir.toml"
SETTINGS_FILE="${PROFILE_DIR}/Ymir.toml"

mkdir -p "${PROFILE_DIR}" "${PROFILE_DIR}/roms/cdb"

if [ ! -e "${SETTINGS_FILE}" ] && [ -e "${DEFAULT_CONFIG}" ]; then
  cp -a "${DEFAULT_CONFIG}" "${SETTINGS_FILE}"
fi

if [ -e "${SETTINGS_FILE}" ]; then
  sed -i "s|^    IPLROMImages = .*|    IPLROMImages = '/storage/roms/bios/saturn'|" "${SETTINGS_FILE}"
  sed -i "/^\[Input.Port1\]$/,/^\[/ s|^PeripheralType = .*|PeripheralType = 'ControlPad'|" "${SETTINGS_FILE}"
fi

if command -v set_kill >/dev/null 2>&1; then
  set_kill set ymir-sa
fi

exec /usr/bin/ymir-sa -p "${PROFILE_DIR}" -f "${ROM}"