# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="armsx2-sa"
PKG_VERSION="ca3a829aa6b48f1438e00b141af6a5116f6169f5"  # tag 2.5.4
PKG_ARCH="aarch64"
PKG_LICENSE="GPL-3.0-or-later"
PKG_SITE="https://github.com/ARMSX2/ARMSX2"
PKG_URL="${PKG_SITE}.git"
PKG_GIT_CLONE_BRANCH="refresh-experimental"
GET_HANDLER_SUPPORT="git"
PKG_LONGDESC="ARMSX2 is a fork of PCSX2 with a native ARM64 JIT for PlayStation 2 emulation."
PKG_TOOLCHAIN="manual"

# PCSX2/ARMSX2 only supports Clang/MSVC (CMake emits an unsupported-compiler
# warning under GCC and codegen quality suffers), so build with the toolchain's
# clang/llvm like pcsx2-sa does.
PKG_DEPENDS_TARGET="toolchain llvm:host zlib curl libpcap alsa-lib dbus shaderc ${VULKAN}"

if [ "${DISPLAYSERVER}" = "wl" ]; then
  PKG_DEPENDS_TARGET+=" wayland ${WINDOWMANAGER} xwayland xrandr libXi"
fi

# USE_OPENGL stays on as a fallback renderer; the default renderer is Vulkan
# (set via ARMSX2.ini Renderer = 14), which is required for playable speed on
# Adreno where the GL path runs through zink.
if [ "${OPENGL_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGL} libglvnd"
elif [ "${OPENGLES_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGLES}"
fi

ARMSX2_CMAKE_OPTS=(
  -DCMAKE_BUILD_TYPE=Release
  -DENABLE_QT_UI=OFF
  -DUSE_BACKTRACE=OFF
  -DUSE_VULKAN=ON
  -DUSE_OPENGL=ON
  -DDISABLE_ADVANCE_SIMD=ON
  -DHOST_PAGE_SIZE=0x1000
  -DHOST_CACHE_LINE_SIZE=64
)

make_target() {
  for _v in CFLAGS CXXFLAGS LDFLAGS; do
    export ${_v}="$(echo ${!_v} | sed 's/-mabi=lp64//g; s/-mtune=[^ ]*//g')"
  done

  # The toolchain's clang defaults to the x86_64 host target. Bundled 3rdparty
  # sub-builds (e.g. libpng's pnglibconf genout) invoke clang with our aarch64
  # *FLAGS but without the --target that CMAKE_*_COMPILER_TARGET adds, so clang
  # rejects -mcpu=armv9-a / -mno-outline-atomics as "unknown x86 CPU". Bake the
  # triple into the flags so every clang invocation targets aarch64.
  export CFLAGS="--target=${TARGET_NAME} ${CFLAGS}"
  export CXXFLAGS="--target=${TARGET_NAME} ${CXXFLAGS}"
  export LDFLAGS="--target=${TARGET_NAME} ${LDFLAGS}"

  # The upstream ARMSX2/ARMSX2 repo has two layers: repo root (PCSX2 upstream
  # files) with an ARMSX2/ subdir holding the ARM64 JIT sources we build. The
  # buildable CMake project lives under ARMSX2/app/src/main/cpp.
  local _src="${PKG_BUILD}/ARMSX2/app/src/main/cpp"

  mkdir -p "${PKG_BUILD}/.${TARGET_NAME}"
  cd "${PKG_BUILD}/.${TARGET_NAME}"

  local -a tgt_opts=(
    -G Ninja
    -S "${_src}"
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
    -DCMAKE_SYSTEM_PROCESSOR=aarch64
    -DCMAKE_C_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_CXX_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_SYSROOT="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
    "${ARMSX2_CMAKE_OPTS[@]}"
  )
  cmake "${tgt_opts[@]}"
  cmake --build "${PKG_BUILD}/.${TARGET_NAME}"
}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp ${PKG_BUILD}/.${TARGET_NAME}/bin/armsx2 ${INSTALL}/usr/bin/armsx2
  chmod +x ${INSTALL}/usr/bin/armsx2

  mkdir -p ${INSTALL}/usr/share/armsx2/assets
  cp -rf ${PKG_BUILD}/ARMSX2/app/src/main/assets/* ${INSTALL}/usr/share/armsx2/assets/

  cp -rf ${PKG_DIR}/scripts/* ${INSTALL}/usr/bin
  chmod +x ${INSTALL}/usr/bin/start_armsx2.sh

  mkdir -p ${INSTALL}/usr/config
  cp -rf ${PKG_DIR}/config/${DEVICE}/armsx2 ${INSTALL}/usr/config
}
