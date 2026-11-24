#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
. /etc/profile

ROM="$1"
GAME="$(basename "${ROM%.*}")"
APP_DIR="/usr/share/spelunkomp"
CONFIG_DIR="/storage/.config/spelunkomp"
SAVE_DIR="/storage/roms/savestates/spelunkomp/${GAME}"

case "${GAME}" in
  agallet|akatana|ddonpach|ddp2|ddpdfk|ddpdfk10|ddpdoj|ddpdojblk|ddpsdoj|deathsml|dfeveron|dfkbl|donpachi|donpachij|dsmbl|espgal|espgal2|esprade|futari10|futari15|futaribl|futariblj|guwange|ibara|ibarablk|ket|mazinger|mmpork|mushisam|pinkswts) ;;
  *) echo "Spelunkomp: unsupported ROM set: ${GAME}" >&2; exit 1 ;;
esac

if [ ! -f "${ROM}" ] || [ "${ROM##*.}" != "zip" ] || [ ! -x "${APP_DIR}/${GAME}" ]; then
  echo "Spelunkomp: a supported ZIP ROM set is required" >&2
  exit 1
fi

set_kill set "-9 ${GAME}"
mkdir -p "${CONFIG_DIR}" "${SAVE_DIR}"
[ -e "${CONFIG_DIR}/shaders" ] || ln -s "${APP_DIR}/shaders" "${CONFIG_DIR}/shaders"
export SDL_VIDEODRIVER=wayland
export LD_LIBRARY_PATH="${APP_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

OPTIONS=(--roms "${ROM}" --settings "${CONFIG_DIR}/settings.ini" --saves "${SAVE_DIR}" --fullscreen)
case "${HW_DEVICE}" in
  H700) OPTIONS+=(--software); export SDL_RENDER_DRIVER=opengles2 ;;
esac

exec "${APP_DIR}/${GAME}" "${OPTIONS[@]}"
