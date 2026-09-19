# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024 ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="armsx3-sa"
PKG_LICENSE="GPLv2"
PKG_LONGDESC="ARMSX3 is an ARM64-focused fork of the RPCS3 PlayStation 3 emulator."
PKG_VERSION="23e119c0ca8853b7bf9793805e6b57f3bfdb6aca"
PKG_SITE="https://github.com/ARMSX2/ARMSX3"
PKG_URL="${PKG_SITE}.git"
PKG_TOOLCHAIN="cmake"
PKG_DEPENDS_TARGET="toolchain llvm qt6 SDL3 ffmpeg curl zlib zstd libpng pugixml \
                    libusb libevdev alsa-lib pulseaudio openal-soft miniupnpc"

if [ "${OPENGL_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGL} glew"
fi
if [ "${VULKAN_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" ${VULKAN} vulkan-headers"
fi

pre_configure_target() {
  # LLVM is linked from the sysroot, drop its build tree to free disk for ARMSX3.
  rm -rf "$(get_build_dir llvm)"

  local CPU_TUNE_FLAGS=""
  case "${DEVICE}" in
    SM8250)
      CPU_TUNE_FLAGS="-mtune=cortex-a77"
      ;;
    SM8750)
      CPU_TUNE_FLAGS="-mtune=oryon-1"
      ;;
  esac

  export CFLAGS="${CFLAGS} ${CPU_TUNE_FLAGS} -DGLEW_EGL"
  export CXXFLAGS="${CXXFLAGS} ${CPU_TUNE_FLAGS} -DGLEW_EGL"

  PKG_CMAKE_OPTS_TARGET+=" -DWITH_LLVM=ON \
                           -DBUILD_LLVM=OFF \
                           -DSTATIC_LINK_LLVM=OFF \
                           -DLLVM_DIR=${SYSROOT_PREFIX}/usr/lib/cmake/llvm \
                           -DARMSX3_ARM_MARCH=armv8.2-a+dotprod+fp16 \
                           -DCMAKE_SYSTEM_PROCESSOR=${TARGET_ARCH} \
                           -DCMAKE_INSTALL_DATADIR=share/armsx3 \
                           -DBUILD_RPCS3_TESTS=OFF \
                           -DUSE_NATIVE_INSTRUCTIONS=OFF \
                           -DUSE_PRECOMPILED_HEADERS=OFF \
                           -DUSE_LTO=ON \
                           -DUSE_DISCORD_RPC=OFF \
                           -DUSE_SYSTEM_FFMPEG=ON \
                           -DUSE_SYSTEM_CURL=ON \
                           -DUSE_SYSTEM_SDL=ON \
                           -DUSE_SYSTEM_ZLIB=ON \
                           -DUSE_SYSTEM_ZSTD=ON \
                           -DUSE_SYSTEM_LIBPNG=ON \
                           -DUSE_SYSTEM_PUGIXML=ON \
                           -DUSE_SYSTEM_LIBUSB=ON \
                           -DUSE_SYSTEM_OPENAL=ON \
                           -DUSE_SYSTEM_MINIUPNPC=ON \
                           -DUSE_SYSTEM_OPENCV=OFF"
}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  DESTDIR=${INSTALL} cmake --install ${PKG_BUILD}/.${TARGET_NAME}
  mv ${INSTALL}/usr/bin/rpcs3 ${INSTALL}/usr/bin/${PKG_NAME}
  safe_remove ${INSTALL}/usr/share/armsx3/rpcs3/test
  safe_remove ${INSTALL}/usr/share/applications/rpcs3.desktop
  safe_remove ${INSTALL}/usr/share/metainfo/rpcs3.metainfo.xml
  safe_remove ${INSTALL}/usr/share/icons/hicolor/scalable/apps/rpcs3.svg
  safe_remove ${INSTALL}/usr/share/icons/hicolor/48x48/apps/rpcs3.png
  cp -rf ${PKG_DIR}/scripts/start_armsx3.sh ${INSTALL}/usr/bin
  chmod 755 ${INSTALL}/usr/bin/*
  mkdir -p ${INSTALL}/usr/config/armsx3
  if [ -d "${PKG_DIR}/config/${DEVICE}" ]; then
    cp -rfH ${PKG_DIR}/config/${DEVICE}/* ${INSTALL}/usr/config/armsx3/
  fi
}
