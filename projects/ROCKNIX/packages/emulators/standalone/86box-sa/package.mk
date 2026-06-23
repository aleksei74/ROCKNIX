# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="86box-sa"
PKG_VERSION="4.2.1"
PKG_LICENSE="GPLv3"
PKG_SITE="https://github.com/86Box/86Box"
PKG_URL="${PKG_SITE}/archive/refs/tags/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain SDL2 openal-soft rtmidi qt6 libpng zlib freetype libslirp"
PKG_LONGDESC="86Box is a low-level x86 emulator that focuses on running old operating systems and software."
PKG_TOOLCHAIN="cmake"

post_unpack() {
  sed -i 's/find_package(Qt\${QT_MAJOR}LinguistTools/# find_package(Qt\${QT_MAJOR}LinguistTools/g' "${PKG_BUILD}/src/qt/CMakeLists.txt"
  sed -i 's/COMMAND "\$<TARGET_FILE:Qt\${QT_MAJOR}::lconvert>".*/COMMAND cmake -E touch "${CMAKE_CURRENT_BINARY_DIR}\/86box_${PO_FILE_NAME}.qm"/g' "${PKG_BUILD}/src/qt/CMakeLists.txt"
  sed -i '/pkg_check_modules(RTMIDI REQUIRED/a \        target_link_libraries(PkgConfig::RTMIDI INTERFACE asound)' "${PKG_BUILD}/src/sound/CMakeLists.txt"
}

pre_configure_target() {
  export LDFLAGS="${LDFLAGS} -fopenmp"
  PKG_CMAKE_OPTS_TARGET+=" -DCMAKE_BUILD_TYPE=Release \
                           -DUSE_QT6=ON \
                           -DNEW_DYNAREC=ON \
                           -DDYNAREC=ON"
}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp -rf ${PKG_BUILD}/.${TARGET_NAME}/src/86Box ${INSTALL}/usr/bin/86box-sa
  cp -rf ${PKG_DIR}/scripts/* ${INSTALL}/usr/bin
  chmod +x ${INSTALL}/usr/bin/*
}
