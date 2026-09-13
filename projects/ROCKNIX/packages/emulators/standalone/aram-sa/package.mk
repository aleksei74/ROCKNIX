# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 ROCKNIX

PKG_NAME="aram-sa"
PKG_VERSION="c2819992a30ce6fb97b73c0d7493bc4b9ae5c133"
PKG_LICENSE="PolyForm-Noncommercial-1.0.0"
PKG_SITE="https://github.com/mirusu400/aram-emu"
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain xwayland libX11 libXcursor libXi libXinerama libXrandr libXxf86vm libglvnd alsa-lib"
PKG_LONGDESC="ARAM emulator for Korean feature-phone WIPI, SKVM, and Raptor software."
PKG_TOOLCHAIN="manual"

ARAM_CORE_VERSION="73760df41f3e4826ac4503c1f868ed07c5adb326"
ARAM_FRONTEND_VERSION="3f3ff549199a4593ba5a7a0e86f59d1494d9658d"
ARAM_AUTHD_VERSION="4053607356dd89e621740388f7ec761e27ecee58"

make_target() {
  PKG_DIR="${PKG_DIR}" \
  ARAM_EMU_REF="${PKG_VERSION}" \
  ARAM_CORE_REF="${ARAM_CORE_VERSION}" \
  ARAM_FRONTEND_REF="${ARAM_FRONTEND_VERSION}" \
  ARAM_AUTHD_REF="${ARAM_AUTHD_VERSION}" \
    bash "${PKG_DIR}/scripts/build_aram_source.sh" "${PKG_BUILD}"
}

makeinstall_target() {
  mkdir -p "${INSTALL}/usr/bin"
  cp "${PKG_BUILD}/aram" "${INSTALL}/usr/bin/aram"
  cp "${PKG_DIR}/scripts/start_aram.sh" "${INSTALL}/usr/bin/start_aram.sh"
  chmod 0755 "${INSTALL}/usr/bin/aram" "${INSTALL}/usr/bin/start_aram.sh"
}
