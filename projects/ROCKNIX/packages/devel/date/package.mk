# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="date"
PKG_VERSION="3.0.4"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/HowardHinnant/date"
PKG_URL="${PKG_SITE}/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Howard Hinnant's date and time library for C++."
PKG_TOOLCHAIN="cmake"

pre_configure_target() {
  PKG_CMAKE_OPTS_TARGET+=" -DCMAKE_BUILD_TYPE=Release \
                           -DBUILD_SHARED_LIBS=OFF \
                           -DENABLE_DATE_INSTALL=ON \
                           -DENABLE_DATE_TESTING=OFF \
                           -DBUILD_TZ_LIB=OFF \
                           -DUSE_SYSTEM_TZ_DB=OFF \
                           -DMANUAL_TZ_DB=OFF \
                           -DUSE_TZ_DB_IN_DOT=OFF"
}
