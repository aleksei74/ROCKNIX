# SPDX-License-Identifier: GPL-3.0-or-later

PKG_NAME="hakux-sa"
PKG_VERSION="e11ee60b90742a368a08f7f5339af10048a63a04"
PKG_LICENSE="GPL-3.0-or-later"
PKG_SITE="https://github.com/rfandango/hakuX"
PKG_URL="${PKG_SITE}.git"
PKG_GIT_SUBMODULES="external/fex"
PKG_LONGDESC="Experimental ARM64 Linux port of the hakuX Xbox emulator"
PKG_TOOLCHAIN="manual"
PKG_DEPENDS_TARGET="toolchain SDL3 libfmt vulkan-loader vulkan-headers zlib glslang"

hakux_fetch() {
  local url="$1" revision="$2" dest="$3"
  if [ ! -d "${dest}/.git" ]; then
    mkdir -p "$(dirname "${dest}")"
    git clone --filter=blob:none --no-checkout "${url}" "${dest}" || return 1
  fi
  git -C "${dest}" fetch --depth=1 origin "${revision}" || return 1
  git -C "${dest}" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD
}

pre_configure_target() {
  case "${DEVICE}" in
    SM8250|SM8550|SM8750) ;;
    *) return 1 ;;
  esac
  git -C "${PKG_BUILD}" submodule update --init --depth=1 external/fex || return 1
  git -C "${PKG_BUILD}/external/fex" submodule update --init --depth=1 \
    External/fmt External/range-v3 External/rpmalloc \
    External/unordered_dense External/xxhash Source/Common/cpp-optparse || return 1
  mkdir -p "${PKG_BUILD}/linux"
  cp "${PKG_DIR}/sources/linux/"*.c "${PKG_BUILD}/linux/" || return 1

  local deps="${PKG_BUILD}/.hakux-deps"
  hakux_fetch https://github.com/zeux/volk.git \
    0b17a763ba5643e32da1b2152f8140461b3b7345 "${deps}/volk" || return 1
  hakux_fetch https://github.com/KhronosGroup/glslang.git \
    b5782e52ee2f7b3e40bb9c80d15b47016e008bc9 "${deps}/glslang" || return 1
  hakux_fetch https://github.com/KhronosGroup/SPIRV-Reflect.git \
    ef913b3ab3da1becca3cf46b15a10667c67bebe5 "${deps}/spirv_reflect" || return 1
  hakux_fetch https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git \
    1d8f600fd424278486eade7ed3e877c99f0846b1 "${deps}/vma" || return 1
  hakux_fetch https://github.com/xemu-project/nv2a_vsh_cpu.git \
    561fe80da57a881f89000256b459440c0178a7ce \
    "${deps}/root/subprojects/nv2a_vsh_cpu" || return 1
}

make_target() {
  local deps="${PKG_BUILD}/.hakux-deps"
  local out="${PKG_BUILD}/.${TARGET_NAME}"
  local clang="${TOOLCHAIN}/bin"

  cmake -G Ninja -S "${PKG_BUILD}/native" -B "${out}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_SYSROOT="${SYSROOT_PREFIX}" \
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT_PREFIX}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_C_COMPILER="${clang}/clang" \
    -DCMAKE_C_COMPILER_TARGET="${TARGET_NAME}" \
    -DCMAKE_CXX_COMPILER="${clang}/clang++" \
    -DCMAKE_CXX_COMPILER_TARGET="${TARGET_NAME}" \
    -DCMAKE_C_FLAGS="-O2 -fPIC" \
    -DCMAKE_CXX_FLAGS="-O2 -fPIC" \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
    -DHAKUX_LTO=OFF \
    -DHAKUX_ARCH="armv8.2-a+fp16+dotprod+rcpc" \
    -DNC_DEPS="${deps}" \
    -DHAKUX_FEX_DIR="${PKG_BUILD}/external/fex" || return 1
  ninja -C "${out}" -j"${CONCURRENCY_MAKE_LEVEL:-4}" hakux-sa
}

makeinstall_target() {
  DESTDIR="${INSTALL}" cmake --install "${PKG_BUILD}/.${TARGET_NAME}" || return 1
  install -Dm755 "${PKG_DIR}/scripts/start_hakux.sh" "${INSTALL}/usr/bin/start_hakux.sh"
  install -Dm644 "${PKG_BUILD}/COPYING" "${INSTALL}/usr/share/licenses/hakux-sa/COPYING"
}
