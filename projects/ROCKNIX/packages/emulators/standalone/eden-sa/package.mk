# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="eden-sa"
PKG_VERSION="5a67d650e64ec45e90ef8c833209eaa95ede1620" # 260526
PKG_LICENSE="GPLv2"
PKG_DEPENDS_TARGET="toolchain llvm:host SDL3 boost libevdev libdrm ffmpeg zlib zstd alsa-lib qt6 libfmt"
PKG_LONGDESC="Eden is a high-performance and easy-to-use emulator, tailored for enthusiasts and developers alike."
PKG_SITE="https://github.com/UzuCore/eden"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_TOOLCHAIN="manual"

if [ ! "${OPENGL}" = "no" ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGL} glu libglvnd"
fi

if [ "${OPENGLES_SUPPORT}" = yes ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGLES}"
fi

if [ "${VULKAN_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" vulkan-loader vulkan-headers"
fi

EDEN_LLVM_BIN="${TOOLCHAIN}/bin"

PGO_URL="https://github.com/Eden-CI/PGO/releases/download/v020525/eden.profdata"
PGO_FILE="${PKG_BUILD}/eden.profdata"

post_unpack_target() {
  find "${PKG_BUILD}" \( -name "CMakeLists.txt" -o -name "*.cmake" \) \
    -exec sed -i 's/\(-\)\?Werror/-Wno-error/g' {} +
}

make_target() {
  local CPU_FIX=""
  local OPT_FLAGS="-O3"
  local LTO_FLAGS="-flto=thin -fuse-ld=lld -Wl,--lto-O3"
  local USE_PGO="yes"
  local USE_FAST_MATH="ON"

  case "${DEVICE}" in
    SM6115)
      # Snapdragon 662 class: keep ARMv8-A compatible instructions.
      CPU_FIX="-march=armv8-a -mtune=cortex-a73"
      USE_FAST_MATH="OFF"
      ;;
    SM8250)
      # Snapdragon 865 class: Cortex-A77/A55, ARMv8.2-A is safe.
      CPU_FIX="-march=armv8.2-a+crc+crypto -mtune=cortex-a77"
      ;;
    SM8550)
      # Known-good path for Snapdragon 8 Gen 2. Preserve the working tuning.
      CPU_FIX="-mcpu=cortex-a78 -mtune=cortex-a78"
      ;;
    SM8650)
      # Snapdragon 8 Gen 3 class. Avoid newer ARMv9 tuning names for older clang.
      CPU_FIX="-march=armv8.2-a+crc+crypto -mtune=cortex-a78"
      ;;
    SM8750)
      # Snapdragon 8 Elite / custom Oryon class. Keep instructions conservative.
      CPU_FIX="-march=armv8.2-a+crc+crypto -mtune=generic"
      ;;
    *)
      CPU_FIX="-march=armv8-a -mtune=generic"
      USE_PGO="no"
      USE_FAST_MATH="OFF"
      ;;
  esac

  local PGO_FLAGS=""
  if [ "${USE_PGO}" = "yes" ]; then
    if [ ! -f "$PGO_FILE" ]; then
      echo "Downloading PGO profile data..."
      curl -L --max-time 300 --retry 3 "$PGO_URL" -o "$PGO_FILE" || {
        echo "Warning: PGO download failed, building without PGO"
        PGO_FILE=""
      }
    fi

    if [ -f "$PGO_FILE" ]; then
      PGO_FLAGS="-fprofile-use=${PGO_FILE} -Wno-backend-plugin -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date"
    fi
  fi

  local FLAGS_CLEAN="s/-mabi=lp64//g; s/-mcpu=cortex-x[34]//g; s/-march=armv9[^ ]*//g"

  for _v in CFLAGS CXXFLAGS; do
    export ${_v}="$(echo ${!_v} | sed -e "$FLAGS_CLEAN") ${OPT_FLAGS} ${PGO_FLAGS} ${CPU_FIX} ${LTO_FLAGS}"
  done

  export LDFLAGS="$(echo ${LDFLAGS} | sed -e "$FLAGS_CLEAN" -e 's/-fuse-ld=bfd/-fuse-ld=lld/g') ${PGO_FLAGS} ${LTO_FLAGS}"

  export AR="${EDEN_LLVM_BIN}/llvm-ar"
  export RANLIB="${EDEN_LLVM_BIN}/llvm-ranlib"
  export NM="${EDEN_LLVM_BIN}/llvm-nm"
  export CC="${EDEN_LLVM_BIN}/clang"
  export CXX="${EDEN_LLVM_BIN}/clang++"
  export LD="${EDEN_LLVM_BIN}/ld.lld"

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

    -DCMAKE_C_COMPILER="${EDEN_LLVM_BIN}/clang"
    -DCMAKE_C_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_CXX_COMPILER="${EDEN_LLVM_BIN}/clang++"
    -DCMAKE_CXX_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_ASM_COMPILER="${EDEN_LLVM_BIN}/clang"
    -DCMAKE_ASM_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_C_FLAGS="${CPU_FIX} ${OPT_FLAGS}"
    -DCMAKE_CXX_FLAGS="${CPU_FIX} ${OPT_FLAGS}"

    -DCMAKE_LINKER="${EDEN_LLVM_BIN}/ld.lld"
    -DCMAKE_AR="${EDEN_LLVM_BIN}/llvm-ar"
    -DCMAKE_RANLIB="${EDEN_LLVM_BIN}/llvm-ranlib"
    -DCMAKE_NM="${EDEN_LLVM_BIN}/llvm-nm"

    -DYUZU_BUILD_PRESET=generic
    -DENABLE_QT_TRANSLATION=ON
    -DUSE_DISCORD_PRESENCE=OFF
    -DYUZU_USE_BUNDLED_SIRIT=ON
    -DYUZU_USE_BUNDLED_QT=OFF
    -DYUZU_USE_BUNDLED_SDL3=OFF
    -DYUZU_TESTS=OFF
    -DYUZU_USE_QT_MULTIMEDIA=OFF
    -DYUZU_USE_QT_WEB_ENGINE=OFF
    -DYUZU_ROOM=ON
    -DYUZU_ROOM_STANDALONE=OFF
    -DYUZU_CMD=OFF
    -DVulkanHeaders_FORCE_BUNDLED=ON
    -DENABLE_LTO=OFF
    -DUSE_FAST_MATH="${USE_FAST_MATH}"
  )

  cmake "${tgt_opts[@]}" || return 1
  find . \( -name "*.ninja" -o -name "flags.make" \) \
    -exec sed -i 's/-Werror/-Wno-error/g' {} + 2>/dev/null

  ninja -j$(nproc) || ninja
}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp ${PKG_BUILD}/.${TARGET_NAME}/bin/eden ${INSTALL}/usr/bin/ || return 1
  [ -d "${PKG_DIR}/scripts" ] && cp -rf ${PKG_DIR}/scripts/* ${INSTALL}/usr/bin/
  chmod 755 ${INSTALL}/usr/bin/*

  mkdir -p ${INSTALL}/usr/config/eden
  [ -d "${PKG_DIR}/config/${DEVICE}" ] && cp -rf ${PKG_DIR}/config/${DEVICE}/* ${INSTALL}/usr/config/eden/
}
