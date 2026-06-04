# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="neargye-semver"
PKG_VERSION="1.0.0-rc"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/Neargye/semver"
PKG_URL="${PKG_SITE}/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Neargye semver is a header-only semantic versioning parser for C++."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p "${SYSROOT_PREFIX}/usr/include"
  cp -a "${PKG_BUILD}/include/semver.hpp" "${SYSROOT_PREFIX}/usr/include/semver.hpp" || return 1
}
