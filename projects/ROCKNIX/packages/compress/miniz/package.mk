# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="miniz"
PKG_VERSION="3.1.0"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/richgel999/miniz"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Miniz is a lossless, high performance data compression library."
PKG_TOOLCHAIN="cmake"

pre_configure_target() {
  PKG_CMAKE_OPTS_TARGET+=" -DCMAKE_BUILD_TYPE=Release \
                           -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
                           -DBUILD_SHARED_LIBS=OFF \
                           -DBUILD_EXAMPLES=OFF \
                           -DBUILD_FUZZERS=OFF \
                           -DBUILD_TESTS=OFF \
                           -DBUILD_HEADER_ONLY=OFF \
                           -DINSTALL_PROJECT=ON"
}
