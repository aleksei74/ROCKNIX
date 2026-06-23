# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="stb"
PKG_VERSION="f58f558c120e9b32c217290b80bad1a0729fbb2c"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/nothings/stb"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="stb is a collection of single-file public domain/MIT libraries for C/C++."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p "${SYSROOT_PREFIX}/usr/include/stb"
  cp -a "${PKG_BUILD}"/*.h "${SYSROOT_PREFIX}/usr/include/stb/" || return 1

  # Match vcpkg's find-package behavior used by Ymir:
  #   find_package(Stb REQUIRED)
  #   target_include_directories(... ${Stb_INCLUDE_DIR})
  mkdir -p "${SYSROOT_PREFIX}/usr/lib/cmake/Stb"
  cat >"${SYSROOT_PREFIX}/usr/lib/cmake/Stb/StbConfig.cmake" <<EOF
set(Stb_FOUND TRUE)
set(Stb_INCLUDE_DIR "\${CMAKE_CURRENT_LIST_DIR}/../../../include/stb")
set(Stb_INCLUDE_DIRS "\${Stb_INCLUDE_DIR}")

if(NOT TARGET Stb::Stb)
  add_library(Stb::Stb INTERFACE IMPORTED)
  set_target_properties(Stb::Stb PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "\${Stb_INCLUDE_DIR}"
  )
endif()
EOF

  cp -a "${SYSROOT_PREFIX}/usr/lib/cmake/Stb/StbConfig.cmake" \
        "${SYSROOT_PREFIX}/usr/lib/cmake/Stb/stb-config.cmake"

  cat >"${SYSROOT_PREFIX}/usr/lib/cmake/Stb/StbConfigVersion.cmake" <<EOF
set(PACKAGE_VERSION "${PKG_VERSION}")
set(PACKAGE_VERSION_COMPATIBLE TRUE)
EOF
}
