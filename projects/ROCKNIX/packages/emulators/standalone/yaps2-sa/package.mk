# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2025-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="yaps2-sa"
PKG_VERSION="76bba7ffd3c278221de8ad19a6fcddddb3692432"
PKG_LICENSE="GPLv3"
PKG_SITE="https://github.com/yaps2/yaps2"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_LONGDESC="yaps2 is an ARM64-focused PlayStation 2 (PS2) emulator, a fork of PCSX2."
PKG_DEPENDS_TARGET="toolchain llvm:host SDL3 libpng zlib libjpeg-turbo zstd lz4 libwebp freetype plutosvg curl libpcap ffmpeg libX11 libXext qt6 shaderc"
PKG_TOOLCHAIN="manual"
PKG_BUILD_FLAGS="speed"

# Use the release asset, not the "latest" source archive. The source archive
# nests every pnach under "pcsx2_patches-latest/patches/", but PCSX2 looks
# patches up at the zip root as "<serial>_<crc>.pnach" (Patch.cpp:
# GetPnachTemplate has no directory prefix), so those never match. The release
# asset ships the pnach files flat at the root, as PCSX2 expects.
PATCHES_URL="https://github.com/PCSX2/pcsx2_patches/releases/download/latest/patches.zip"

get_graphicdrivers() {
  if listcontains "${GRAPHIC_DRIVERS}" "(panfrost)"; then
    GRAPHICS_DRIVER="panfrost"
  elif listcontains "${GRAPHIC_DRIVERS}" "(freedreno)"; then
    GRAPHICS_DRIVER="freedreno"
  fi
}

pre_configure_target() {
  PCSX2_CMAKE_BASE=(
    -DCMAKE_BUILD_TYPE=Release
    # Full-tree IPO stays off for Qt (not worth it)...
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
    # ...but stays on for just the recompiler/VU/EE/IOP core:
    -DLTO_PCSX2_CORE=ON
    -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON
    -DUSE_VULKAN=ON
    -DUSE_OPENGL=ON
    -DUSE_BACKTRACE=OFF
    -DENABLE_QT_UI=ON
    -DENABLE_QT_DEBUGGER=OFF
    -DWAYLAND_API=ON
    -DX11_API=ON
    -DCMAKE_LINKER_TYPE=LLD
  )

  # RK3576's Cortex-A72 is ARMv8.0-A and lacks LSE atomics; PCSX2's default
  # -march=armv8.1-a emits LSE instructions that SIGILL on it. Current upstream
  # honors an explicit -march in CMAKE_CXX_FLAGS and skips its ARMv8.1 default.
  case ${DEVICE} in
    RK3576)
      PCSX2_CMAKE_BASE+=(
        -DCMAKE_C_FLAGS=-march=armv8-a+crc+crypto
        -DCMAKE_CXX_FLAGS=-march=armv8-a+crc+crypto
      )
    ;;
  esac

  case ${TARGET_ARCH} in
    aarch64)
      for _v in CFLAGS CXXFLAGS LDFLAGS; do
        export ${_v}="$(echo ${!_v} | sed 's/-march=[^ ]*//g; s/-mabi=lp64//g; s/-mtune=[^ ]*//g')"
      done
    ;;
    x86_64)
      for _v in CFLAGS CXXFLAGS LDFLAGS; do
        export ${_v}="$(echo ${!_v} | sed 's/-mabi=lp64//g; s/-mtune=[^ ]*//g')"
      done
    ;;
  esac

  # LTO archives contain LLVM bitcode and must be linked with lld. ROCKNIX's
  # global LDFLAGS may select bfd, which CMake appends after our *_FLAGS_INIT.
  export LDFLAGS="$(echo ${LDFLAGS} | sed 's/-fuse-ld=[^ ]*//g')"
}

make_target() {
  mkdir -p "${PKG_BUILD}/.${TARGET_NAME}"
  cd "${PKG_BUILD}/.${TARGET_NAME}"

  local -a tgt_opts=(
    -G Ninja
    -S "${PKG_BUILD}"
    -B "${PKG_BUILD}/.${TARGET_NAME}"
    -DCMAKE_INSTALL_PREFIX=/usr
    -DCMAKE_MAKE_PROGRAM=ninja
    -DCMAKE_C_COMPILER="${TOOLCHAIN}/bin/clang"
    -DCMAKE_CXX_COMPILER="${TOOLCHAIN}/bin/clang++"
    -DCMAKE_AR="${TOOLCHAIN}/bin/llvm-ar"
    -DCMAKE_RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
    -DCMAKE_NM="${TOOLCHAIN}/bin/llvm-nm"
    -DCMAKE_OBJCOPY="${TOOLCHAIN}/bin/llvm-objcopy"
    -DCMAKE_OBJDUMP="${TOOLCHAIN}/bin/llvm-objdump"
    -DCMAKE_STRIP="${TOOLCHAIN}/bin/llvm-strip"
    -DCMAKE_C_COMPILER_AR="${TOOLCHAIN}/bin/llvm-ar"
    -DCMAKE_CXX_COMPILER_AR="${TOOLCHAIN}/bin/llvm-ar"
    -DCMAKE_C_COMPILER_RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
    -DCMAKE_CXX_COMPILER_RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
    -DCMAKE_EXE_LINKER_FLAGS_INIT="-fuse-ld=lld"
    -DCMAKE_MODULE_LINKER_FLAGS_INIT="-fuse-ld=lld"
    -DCMAKE_SHARED_LINKER_FLAGS_INIT="-fuse-ld=lld"
    -DCMAKE_SYSTEM_NAME=Linux
    -DCMAKE_SYSTEM_PROCESSOR=${TARGET_ARCH}
    -DCMAKE_C_COMPILER_TARGET=${TARGET_NAME}
    -DCMAKE_CXX_COMPILER_TARGET=${TARGET_NAME}
    -DCMAKE_SYSROOT="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
    -DLLVM_DIR="${TOOLCHAIN}/lib/cmake/llvm"
    -DCMAKE_AR="${TOOLCHAIN}/bin/llvm-ar"
    -DCMAKE_RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
    "${PCSX2_CMAKE_BASE[@]}"
  )
  cmake "${tgt_opts[@]}"
  cmake --build "${PKG_BUILD}/.${TARGET_NAME}"
  ninja install
  wget -c -t 5 -O "bin/resources/patches.zip" ${PATCHES_URL}
}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp -rf ${PKG_DIR}/scripts/* ${INSTALL}/usr/bin
  chmod 755 ${INSTALL}/usr/bin/*

  mkdir -p ${INSTALL}/usr/share/yaps2-sa
  cp -rf ${PKG_BUILD}/.${TARGET_NAME}/bin/* ${INSTALL}/usr/share/yaps2-sa

  mkdir -p ${INSTALL}/usr/config
  cp -rf ${PKG_DIR}/config/common/YAPS2 ${INSTALL}/usr/config

  case ${DEVICE} in
    S922X)
      cp -rf ${PKG_DIR}/config/S922X/YAPS2 ${INSTALL}/usr/config
    ;;
    *)
      cp -rf ${PKG_DIR}/config/inputplumber/YAPS2 ${INSTALL}/usr/config
    ;;
  esac
}

post_install() {
  case ${GRAPHICS_DRIVER} in
    panfrost)
      GRAPHICS="export MESA_GL_VERSION_OVERRIDE=3.3 MESA_GLSL_VERSION_OVERRIDE=330"
    ;;
    *)
      GRAPHICS=""
    ;;
  esac

  sed -e "s/@GRAPHICS@/${GRAPHICS}/g" \
        -i ${INSTALL}/usr/bin/start_yaps2.sh
}
