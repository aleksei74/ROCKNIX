# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 ROCKNIX

PKG_NAME="sm2-emu-sa"
PKG_VERSION="f7648a99b5bb3d05f880493e8db0593bae157e28"
PKG_LICENSE="GPL-3.0-or-later"
PKG_SITE="https://github.com/Keisho-Emu/Keisho"
PKG_URL="${PKG_SITE}.git"
PKG_GIT_SUBMODULE_DEPTH="1"
PKG_GIT_SUBMODULES="3rdparty/musashi 3rdparty/ymfm 3rdparty/VulkanMemoryAllocator \
                    3rdparty/imgui 3rdparty/miniz 3rdparty/pugixml 3rdparty/SDL \
                    3rdparty/SheenBidi 3rdparty/harfbuzz"
PKG_LONGDESC="Keisho Sega Model 1, Model 2 and Model 3 arcade emulator"
PKG_DEPENDS_TARGET="toolchain shaderc:host SDL3 pugixml harfbuzz fontconfig curl"

PKG_CMAKE_OPTS_TARGET+=" -DCMAKE_BUILD_TYPE=Release \
                         -DSM2_GLSLC=${TOOLCHAIN}/bin/glslc \
                         -DSM2_M68KMAKE_HOST_CC=${TOOLCHAIN}/bin/host-gcc \
                         -DSM2_BUILD_TESTS=OFF"

if [ "${ARCH}" = "x86_64" ]; then
  PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_OPENGL_ES=OFF"
  if [ -n "${OPENGL}" ] && [ "${OPENGL}" != "no" ]; then
    PKG_DEPENDS_TARGET+=" ${OPENGL}"
    PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_OPENGL_DESKTOP=ON"
  else
    PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_OPENGL_DESKTOP=OFF"
  fi
else
  PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_OPENGL_DESKTOP=OFF"
  if [ -n "${OPENGLES}" ] && [ "${OPENGLES}" != "no" ]; then
    PKG_DEPENDS_TARGET+=" ${OPENGLES}"
    PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_OPENGL_ES=ON"
  else
    PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_OPENGL_ES=OFF"
  fi
fi

if [ "${VULKAN_SUPPORT}" = "yes" ] && [ -n "${VULKAN}" ] && [ "${VULKAN}" != "no" ]; then
  PKG_DEPENDS_TARGET+=" ${VULKAN}"
  PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_VULKAN=ON"
else
  PKG_CMAKE_OPTS_TARGET+=" -DSM2_BUILD_VULKAN=OFF"
fi

pre_unpack() {
  local source_dir="${SOURCES}/${PKG_NAME}/${PKG_SOURCE_NAME}"
  local status

  status="$(git -C "${source_dir}" submodule status -- ${PKG_GIT_SUBMODULES})" || return 1
  if grep -qE '^[-+U]' <<< "${status}"; then
    git -C "${source_dir}" submodule update --init --depth=1 --jobs=4 -- ${PKG_GIT_SUBMODULES} || return 1
  fi
}

makeinstall_target() {
  DESTDIR="${INSTALL}" cmake --install "${PKG_BUILD}/.${TARGET_NAME}" --prefix /usr || return 1
  install -Dm755 "${PKG_DIR}/scripts/start_sm2-emu.sh" "${INSTALL}/usr/bin/start_sm2-emu.sh"
}
