# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="tomlplusplus"
PKG_VERSION="3.4.0"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/marzer/tomlplusplus"
PKG_URL="${PKG_SITE}/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="toml++ is a header-only TOML config file parser and serializer for C++17."
PKG_TOOLCHAIN="cmake"

pre_configure_target() {
  PKG_CMAKE_OPTS_TARGET+=" -DCMAKE_BUILD_TYPE=Release \
                           -DBUILD_EXAMPLES=OFF"
}
