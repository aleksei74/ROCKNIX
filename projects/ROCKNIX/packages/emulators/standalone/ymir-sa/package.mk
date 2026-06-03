# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="ymir-sa"
PKG_VERSION="4bc72936451eac128170beb8e51f30cf900120c1"
PKG_LICENSE="GPLv3"
PKG_SITE="https://github.com/StrikerX3/Ymir"
PKG_URL="${PKG_SITE}.git"
PKG_LONGDESC="Ymir is a work-in-progress Sega Saturn emulator."
PKG_ARCH="aarch64"
PKG_TOOLCHAIN="manual"
GET_HANDLER_SUPPORT="git"
PKG_BUILD_FLAGS="+speed"

# Ymir upstream builds most non-vendored libraries through vcpkg.
# ROCKNIX currently has SDL3/curl/openssl/zlib/zstd. Ymir's vcpkg-style CMake
# deps are provided here as system packages; most are header-only/interface
# targets except rtmidi and miniz.
PKG_DEPENDS_TARGET="toolchain llvm:host SDL3 curl openssl zlib zstd miniz cereal cxxopts date rtmidi tomlplusplus libfmt stb neargye-semver alsa-lib"

if [ "${VULKAN_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" ${VULKAN} vulkan-loader vulkan-headers"
fi

YMIR_LLVM_BIN="${TOOLCHAIN}/bin"

post_unpack() {
  git -C "${PKG_BUILD}" submodule update --init --recursive

  # Upstream links the vcpkg curl target. ROCKNIX/system CMake provides
  # CURL::libcurl through FindCURL instead.
  sed -i 's/CURL::libcurl_static/CURL::libcurl/g' \
    "${PKG_BUILD}/apps/ymir-sdl3/CMakeLists.txt"

  # ROCKNIX curl does not necessarily expose vcpkg's optional HTTP/3 headers.
  # These are only used to show dependency versions in the About window.
  sed -i '/#include <nghttp3\/version.h>/d; /#include <ngtcp2\/version.h>/d; /nghttp3.*NGHTTP3_VERSION/d; /ngtcp2.*NGTCP2_VERSION/d' \
    "${PKG_BUILD}/apps/ymir-sdl3/src/app/ui/windows/about_window.cpp"
}

make_target() {
  export AR="${YMIR_LLVM_BIN}/llvm-ar"
  export RANLIB="${YMIR_LLVM_BIN}/llvm-ranlib"
  export NM="${YMIR_LLVM_BIN}/llvm-nm"
  export CC="${YMIR_LLVM_BIN}/clang"
  export CXX="${YMIR_LLVM_BIN}/clang++"
  export LD="${YMIR_LLVM_BIN}/ld.lld"

  local CPU_FLAGS=""
  case "${DEVICE}" in
    SM6115)
      CPU_FLAGS="-march=armv8-a -mtune=cortex-a73"
      ;;
    SM8250)
      CPU_FLAGS="-march=armv8.2-a+crc+crypto -mtune=cortex-a77"
      ;;
    SM8550)
      CPU_FLAGS="-mcpu=cortex-a78 -mtune=cortex-a78"
      ;;
    SM8650|SM8750)
      CPU_FLAGS="-march=armv8.2-a+crc+crypto -mtune=generic"
      ;;
    *)
      CPU_FLAGS="-march=armv8-a -mtune=generic"
      ;;
  esac

  local FLAGS_CLEAN="s/-mabi=lp64//g; s/-mcpu=[^ ]*//g; s/-march=[^ ]*//g; s/-mtune=[^ ]*//g"
  for _v in CFLAGS CXXFLAGS; do
    export ${_v}="$(echo ${!_v} | sed -e "${FLAGS_CLEAN}") -O3 ${CPU_FLAGS}"
  done
  export LDFLAGS="$(echo ${LDFLAGS} | sed -e "${FLAGS_CLEAN}" -e 's/-fuse-ld=bfd/-fuse-ld=lld/g') -fuse-ld=lld"

  mkdir -p "${PKG_BUILD}/.${TARGET_NAME}"
  cd "${PKG_BUILD}/.${TARGET_NAME}"

  local -a tgt_opts=(
    -G Ninja
    -S "${PKG_BUILD}"
    -B "${PKG_BUILD}/.${TARGET_NAME}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/usr
    -DCMAKE_SYSTEM_NAME=Linux
    -DCMAKE_SYSTEM_PROCESSOR=aarch64
    -DCMAKE_SYSROOT="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
    -DCMAKE_C_COMPILER="${YMIR_LLVM_BIN}/clang"
    -DCMAKE_C_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_CXX_COMPILER="${YMIR_LLVM_BIN}/clang++"
    -DCMAKE_CXX_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_ASM_COMPILER="${YMIR_LLVM_BIN}/clang"
    -DCMAKE_ASM_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_LINKER="${YMIR_LLVM_BIN}/ld.lld"
    -DCMAKE_AR="${YMIR_LLVM_BIN}/llvm-ar"
    -DCMAKE_RANLIB="${YMIR_LLVM_BIN}/llvm-ranlib"
    -DCMAKE_NM="${YMIR_LLVM_BIN}/llvm-nm"
    -DCMAKE_C_FLAGS="${CPU_FLAGS} -O3 -I${SYSROOT_PREFIX}/usr/include"
    -DCMAKE_CXX_FLAGS="${CPU_FLAGS} -O3 -I${SYSROOT_PREFIX}/usr/include"
    -DYmir_DEV_BUILD=OFF
    -DYmir_ENABLE_TESTS=OFF
    -DYmir_ENABLE_SANDBOX=OFF
    -DYmir_ENABLE_YMDASM=OFF
    -DYmir_ENABLE_DEVLOG=OFF
    -DYmir_ENABLE_DEV_ASSERTIONS=OFF
    -DYmir_ENABLE_IMGUI_DEMO=OFF
    -DYmir_ENABLE_UPDATE_CHECKS=OFF
    -DYmir_FEATUREFLAG_DEFAULT=OFF
    -DYmir_ENABLE_IPO=OFF
  )

  cmake "${tgt_opts[@]}" || return 1
  ninja -j$(nproc) ymir-sdl3 || ninja ymir-sdl3
}

makeinstall_target() {
  mkdir -p "${INSTALL}/usr/bin"
  rm -f "${INSTALL}/usr/bin/ymir-sa"
  install -Dm755 "${PKG_BUILD}/.${TARGET_NAME}/apps/ymir-sdl3/ymir-sdl3" "${INSTALL}/usr/bin/ymir-sa" || return 1
  install -Dm755 "${PKG_DIR}/scripts/start_ymir.sh" "${INSTALL}/usr/bin/start_ymir.sh" || return 1

  ${STRIP:-${TOOLCHAIN}/bin/${TARGET_NAME}-strip} "${INSTALL}/usr/bin/ymir-sa" 2>/dev/null || \
    "${TOOLCHAIN}/bin/llvm-strip" "${INSTALL}/usr/bin/ymir-sa" 2>/dev/null || :

  mkdir -p "${INSTALL}/usr/config/Ymir"
  cp -a "${PKG_DIR}/config/Ymir.toml" "${INSTALL}/usr/config/Ymir/Ymir.toml" || return 1
}
