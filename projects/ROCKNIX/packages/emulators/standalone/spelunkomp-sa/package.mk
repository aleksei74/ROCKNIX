# SPDX-License-Identifier: GPL-3.0-only

PKG_NAME="spelunkomp-sa"
PKG_VERSION="0.1.0-beta.1"
PKG_SHA256="57bd7d220314b66dbfca75aa315c2eeacbdfed310cce60efa7590f5698c3235b"
PKG_ARCH="aarch64"
PKG_LICENSE="GPL-3.0-only"
PKG_SITE="https://github.com/tmcleroy/spelunkomp"
PKG_URL="${PKG_SITE}/releases/download/v${PKG_VERSION}/Spelunkomp-linux-arm64.tar.gz"
PKG_SOURCE_DIR="Spelunkomp"
PKG_DEPENDS_TARGET="toolchain zlib"
PKG_LONGDESC="Statically recompiled Cave arcade games"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  local dest="${INSTALL}/usr/share/spelunkomp"
  mkdir -p "${dest}"
  find "${PKG_BUILD}" -maxdepth 1 -type f -executable -exec install -m755 -t "${dest}" {} + || return 1
  cp -a "${PKG_BUILD}/shaders" "${PKG_BUILD}/licenses" "${dest}/" || return 1
  install -m644 -t "${dest}" "${PKG_BUILD}/LICENSE.txt" "${PKG_BUILD}/THIRD_PARTY_NOTICES.md" "${PKG_BUILD}/SOURCE.txt" || return 1
  install -Dm755 "${PKG_DIR}/scripts/start_spelunkomp.sh" "${INSTALL}/usr/bin/start_spelunkomp.sh"
}
