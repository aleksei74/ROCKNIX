# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="xenia-sa"
PKG_VERSION="7010c86fb14f118ee598d3f76010dc0759b9502a"
PKG_LICENSE="BSD-3-Clause"
PKG_SITE="https://github.com/xenia-canary/xenia-canary"
PKG_URL="${PKG_SITE}.git"
PKG_GIT_CLONE_BRANCH="canary_experimental"
PKG_GIT_SUBMODULE_DEPTH="1"
# Linux/AArch64 dependencies only. Excludes Windows DirectX, x64 JIT, tests,
# lint tooling and the unused portal backend.
PKG_GIT_SUBMODULES="third_party/FFmpeg third_party/FidelityFX-CAS third_party/FidelityFX-FSR \
                    third_party/SDL2 third_party/VulkanMemoryAllocator \
                    third_party/aes_128 third_party/capstone \
                    third_party/cxxopts third_party/date third_party/discord-rpc \
                    third_party/disruptorplus third_party/fmt third_party/glslang \
                    third_party/imgui third_party/pugixml third_party/rapidcsv \
                    third_party/rapidjson third_party/snappy third_party/tabulate \
                    third_party/tomlplusplus third_party/utfcpp third_party/xbyak_aarch64 \
                    third_party/xxhash third_party/zarchive third_party/zlib-ng third_party/zstd"
PKG_LONGDESC="Xenia Canary - Xbox 360 emulator (experimental AArch64 build)."
PKG_DEPENDS_TARGET="toolchain llvm:host Python3:host glslang:host spirv-tools spirv-tools:host \
                    vulkan-loader vulkan-headers gtk3 SDL2 alsa-lib lz4 xwayland"
PKG_TOOLCHAIN="manual"

make_target() {
  local LLVM_BIN="${TOOLCHAIN}/bin"
  local BUILD_DIR="${PKG_BUILD}/.${TARGET_NAME}"
  local CPU_FLAGS=""
  local OPT_FLAGS="-O3 -fPIC"
  local TARGET_FLAGS="--target=aarch64-rocknix-linux-gnu --sysroot=${SYSROOT_PREFIX}"
  local FLAGS_CLEAN="s/-mabi=lp64//g; s/-mcpu=[^ ]*//g; s/-march=[^ ]*//g; s/-mtune=[^ ]*//g"

  case "${DEVICE}" in
    SM8250)
      CPU_FLAGS="-march=armv8.2-a+crc+crypto -mtune=cortex-a77"
      ;;
    SM8550|SM8650|SM8750)
      CPU_FLAGS="-mcpu=cortex-a78 -mtune=cortex-a78"
      ;;
    *)
      CPU_FLAGS="-march=armv8-a -mtune=generic"
      ;;
  esac

  for _v in CFLAGS CXXFLAGS ASMFLAGS; do
    export ${_v}="$(echo ${!_v} | sed -e "${FLAGS_CLEAN}") ${TARGET_FLAGS} ${OPT_FLAGS} ${CPU_FLAGS}"
  done

  export AR="${LLVM_BIN}/llvm-ar"
  export RANLIB="${LLVM_BIN}/llvm-ranlib"
  export NM="${LLVM_BIN}/llvm-nm"
  export CC="${LLVM_BIN}/clang"
  export CXX="${LLVM_BIN}/clang++"
  export LD="${LLVM_BIN}/ld.lld"

  # Shader generation must use host executables during an AArch64 cross build.
  export PATH="${TOOLCHAIN}/bin:${PATH}"
  unset VULKAN_SDK

  mkdir -p "${BUILD_DIR}"
  python3 -c "import runpy; runpy.run_path('${PKG_BUILD}/xenia-build.py')['generate_version_h']('${BUILD_DIR}')" || return 1

  cmake -G Ninja \
    -S "${PKG_BUILD}" \
    -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_SYSROOT="${SYSROOT_PREFIX}" \
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT_PREFIX}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_C_COMPILER="${LLVM_BIN}/clang" \
    -DCMAKE_C_COMPILER_TARGET=aarch64-rocknix-linux-gnu \
    -DCMAKE_CXX_COMPILER="${LLVM_BIN}/clang++" \
    -DCMAKE_CXX_COMPILER_TARGET=aarch64-rocknix-linux-gnu \
    -DCMAKE_ASM_COMPILER="${LLVM_BIN}/clang" \
    -DCMAKE_ASM_COMPILER_TARGET=aarch64-rocknix-linux-gnu \
    -DCMAKE_C_FLAGS="${TARGET_FLAGS} ${CPU_FLAGS} ${OPT_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${TARGET_FLAGS} ${CPU_FLAGS} ${OPT_FLAGS}" \
    -DCMAKE_ASM_FLAGS="${TARGET_FLAGS} ${CPU_FLAGS} ${OPT_FLAGS}" \
    -DCMAKE_LINKER="${LLVM_BIN}/ld.lld" \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
    -DCMAKE_AR="${LLVM_BIN}/llvm-ar" \
    -DCMAKE_RANLIB="${LLVM_BIN}/llvm-ranlib" \
    -DCMAKE_NM="${LLVM_BIN}/llvm-nm" \
    -DPython3_EXECUTABLE="${TOOLCHAIN}/bin/python3" \
    -DXENIA_BUILD_TESTS=OFF \
    -DXENIA_BUILD_MISC=OFF || return 1

  ninja -C "${BUILD_DIR}" xenia-app -j$(nproc) || ninja -C "${BUILD_DIR}" xenia-app
}

makeinstall_target() {
  local XENIA_BIN="${PKG_BUILD}/.${TARGET_NAME}/bin/Linux/xenia_canary"

  if [ ! -x "${XENIA_BIN}" ]; then
    echo "Missing Xenia executable: ${XENIA_BIN}" >&2
    return 1
  fi

  mkdir -p "${INSTALL}/usr/bin"
  cp -v "${XENIA_BIN}" "${INSTALL}/usr/bin/xenia_canary"
  cp -v "${PKG_DIR}/scripts/start_xenia.sh" "${INSTALL}/usr/bin/"
  mkdir -p "${INSTALL}/usr/config/xenia"
  cp -v "${PKG_DIR}/config/xenia-canary.config.toml" "${INSTALL}/usr/config/xenia/"
  chmod 0755 "${INSTALL}/usr/bin/xenia_canary" "${INSTALL}/usr/bin/start_xenia.sh"
}
