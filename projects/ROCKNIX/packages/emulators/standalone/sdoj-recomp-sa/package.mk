# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="sdoj-recomp-sa"
PKG_VERSION="814634c57982baf8a97cc94b8a000ca3c4419ecd"
PKG_LICENSE="GPLv3"
PKG_SITE="https://github.com/eandis/SDOJ-Recomp"
PKG_URL="${PKG_SITE}.git"
PKG_LONGDESC="DoDonPachi Saidaioujou Native Recompilation (ReXGlue)"
PKG_DEPENDS_TARGET="toolchain llvm:host SDL3 boost ffmpeg zlib zstd alsa-lib libfmt gtk3 xwayland"
PKG_TOOLCHAIN="manual"

if [ "${VULKAN_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" vulkan-loader vulkan-headers"
fi

post_unpack_target() {
  local REX_THIRDPARTY_CMAKE="${PKG_BUILD}/thirdparty/rexglue-sdk/thirdparty/CMakeLists.txt"
  if [ -f "${REX_THIRDPARTY_CMAKE}" ]; then
    sed -i 's/-march=armv8-a/-march=armv8-a -DCONFIG_PIC=1/g' "${REX_THIRDPARTY_CMAKE}"
    sed -i 's/HAVE_AV_CONFIG_H/HAVE_AV_CONFIG_H\n    CONFIG_PIC=1/g' "${REX_THIRDPARTY_CMAKE}"
    sed -i 's/target_compile_options(libavcodec PRIVATE -w)/target_compile_options(libavcodec PRIVATE -w -fvisibility=hidden)/g' "${REX_THIRDPARTY_CMAKE}"
    sed -i 's/target_compile_options(libavutil PRIVATE -w)/target_compile_options(libavutil PRIVATE -w -fvisibility=hidden)/g' "${REX_THIRDPARTY_CMAKE}"
  fi

  # Disable shaderSignedZeroInfNanPreserveFloat32 on Mesa Turnip driver to avoid ir3 shader compilation bugs
  local REX_VULKAN_DEV="${PKG_BUILD}/thirdparty/rexglue-sdk/src/ui/vulkan/vulkan_device.cpp"
  if [ -f "${REX_VULKAN_DEV}" ] && ! grep -q "VK_DRIVER_ID_MESA_TURNIP.*shaderSignedZeroInfNanPreserveFloat32 = false" "${REX_VULKAN_DEV}"; then
    sed -i 's/shaderSignedZeroInfNanPreserveFloat32);/shaderSignedZeroInfNanPreserveFloat32);\n    if (properties_1_2_KHR_driver_properties.driverID == VK_DRIVER_ID_MESA_TURNIP) device->properties_.shaderSignedZeroInfNanPreserveFloat32 = false;/g' "${REX_VULKAN_DEV}"
  fi

  local REX_VULKAN_CMD="${PKG_BUILD}/thirdparty/rexglue-sdk/src/graphics/vulkan/command_processor.cpp"
  if [ -f "${REX_VULKAN_CMD}" ]; then
    sed -i 's/REXGPU_DEBUG(/REXGPU_INFO(/g' "${REX_VULKAN_CMD}"
  fi

  local REX_XBOXKRNL_VID="${PKG_BUILD}/thirdparty/rexglue-sdk/src/kernel/xboxkrnl/xboxkrnl_video.cpp"
  if [ -f "${REX_XBOXKRNL_VID}" ]; then
    sed -i 's/assert_true(\*frontbuffer_ptr == frontbuffer_virtual_address);/\/\/ assert_true/g' "${REX_XBOXKRNL_VID}"
    sed -i 's/assert_true(frontbuffer_physical_address != UINT32_MAX);/\/\/ assert_true/g' "${REX_XBOXKRNL_VID}"
    python3 <<-EOF
import re
from pathlib import Path

path = Path('${REX_XBOXKRNL_VID}')
content = path.read_text()
content = re.sub(
    r'\s*assert_true\(texture_format\s*==\s*'
    r'rex::graphics::xenos::TextureFormat::k_8_8_8_8\s*\|\|\s*'
    r'texture_format\s*==\s*'
    r'rex::graphics::xenos::TextureFormat::k_2_10_10_10_AS_16_16_16_16\);',
    '\n  // Accept the guest-provided front-buffer format.',
    content,
)
path.write_text(content)
EOF
  fi

  local REX_UI_GTK="${PKG_BUILD}/thirdparty/rexglue-sdk/src/ui/window_gtk.cpp"
  if [ -f "${REX_UI_GTK}" ] && ! grep -q "gtk_widget_set_app_paintable(drawing_area_, TRUE)" "${REX_UI_GTK}"; then
    sed -i 's/gtk_widget_show_all(window_);/gtk_widget_set_double_buffered(drawing_area_, FALSE);\n  gtk_widget_set_app_paintable(drawing_area_, TRUE);\n  gtk_widget_show_all(window_);/g' "${REX_UI_GTK}"
  fi

  local REX_UI_VULKAN_PRES="${PKG_BUILD}/thirdparty/rexglue-sdk/src/ui/vulkan/vulkan_presenter.cpp"
  if [ -f "${REX_UI_VULKAN_PRES}" ]; then
    sed -i 's/VulkanPresenter: The surface doesn\x27t support identity/\/\/ VulkanPresenter: rotate panel support/g' "${REX_UI_VULKAN_PRES}"
  fi

  # Avoid a Turnip ir3 pipeline compilation hang caused by the NMin-based
  # signed-zero test. Multiplication is safe here because only equality with
  # zero is tested, and lets SDOJ finish creating its graphics pipelines.
  local REX_SPIRV_ALU="${PKG_BUILD}/thirdparty/rexglue-sdk/src/graphics/pipeline/shader/spirv_translator_alu.cpp"
  if [ -f "${REX_SPIRV_ALU}" ]; then
    python3 <<-EOF
	import re
	from pathlib import Path

	path = Path('${REX_SPIRV_ALU}')
	content = path.read_text()
	content = re.sub(
	    r'createBinBuiltinCall\s*\(\s*([^,]+?)\s*,\s*ext_inst_glsl_std_450_\s*,\s*GLSLstd450NMin\s*,\s*([^,]+?)\s*,\s*([^)]+?)\s*\)',
	    lambda match: 'createBinOp(spv::OpFMul, ' + match.group(1).strip() + ', ' + match.group(2).strip() + ', ' + match.group(3).strip() + ')',
	    content,
	    flags=re.DOTALL,
	)
	path.write_text(content)
	EOF
  fi

}

pre_configure_target() {
  post_unpack_target
}

make_target() {
  local LLVM_BIN="${TOOLCHAIN}/bin"
  local CPU_FLAGS=""
  case "${DEVICE}" in
    SM8250)
      CPU_FLAGS="-march=armv8.2-a+crc+crypto -mtune=cortex-a77"
      ;;
    SM8550|SM8650|SM8750)
      CPU_FLAGS="-mcpu=cortex-a78 -mtune=cortex-a78"
      ;;
    *)
      if [ -n "${TARGET_CPU}" ] && [[ "${TARGET_CPU}" != *.* ]]; then
        CPU_FLAGS="-mcpu=${TARGET_CPU}${TARGET_CPU_FLAGS}"
      else
        CPU_FLAGS="-march=armv8-a -mtune=generic"
      fi
      ;;
  esac

  local OPT_FLAGS="-O3 -fPIC"
  local FLAGS_CLEAN="s/-mabi=lp64//g; s/-mcpu=[^ ]*//g; s/-march=[^ ]*//g; s/-mtune=[^ ]*//g"

  for _v in CFLAGS CXXFLAGS ASMFLAGS; do
    export ${_v}="$(echo ${!_v} | sed -e "$FLAGS_CLEAN") ${OPT_FLAGS} ${CPU_FLAGS}"
  done

  export LDFLAGS="$(echo ${LDFLAGS} | sed -e "$FLAGS_CLEAN" -e 's/-fuse-ld=bfd/-fuse-ld=lld/g') -Wl,-Bsymbolic"
  export SHARED_LDFLAGS="$(echo ${SHARED_LDFLAGS} | sed -e 's/-fuse-ld=bfd/-fuse-ld=lld/g') -Wl,-Bsymbolic"

  export AR="${LLVM_BIN}/llvm-ar"
  export RANLIB="${LLVM_BIN}/llvm-ranlib"
  export NM="${LLVM_BIN}/llvm-nm"
  export CC="${LLVM_BIN}/clang"
  export CXX="${LLVM_BIN}/clang++"
  export LD="${LLVM_BIN}/ld.lld"

  post_unpack_target

  mkdir -p "${PKG_BUILD}/.${TARGET_NAME}"
  cd "${PKG_BUILD}/.${TARGET_NAME}"

  local -a tgt_opts=(
    -G Ninja
    -S "${PKG_BUILD}"
    -B "${PKG_BUILD}/.${TARGET_NAME}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/usr
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON

    -DCMAKE_SYSTEM_NAME=Linux
    -DCMAKE_SYSTEM_PROCESSOR=aarch64
    -DCMAKE_SYSROOT="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT_PREFIX}"
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY

    -DCMAKE_C_COMPILER="${LLVM_BIN}/clang"
    -DCMAKE_C_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_CXX_COMPILER="${LLVM_BIN}/clang++"
    -DCMAKE_CXX_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_ASM_COMPILER="${LLVM_BIN}/clang"
    -DCMAKE_ASM_COMPILER_TARGET=aarch64-rocknix-linux-gnu
    -DCMAKE_C_FLAGS="${CPU_FLAGS} ${OPT_FLAGS}"
    -DCMAKE_CXX_FLAGS="${CPU_FLAGS} ${OPT_FLAGS}"
    -DCMAKE_ASM_FLAGS="${CPU_FLAGS} ${OPT_FLAGS}"

    -DCMAKE_LINKER="${LLVM_BIN}/ld.lld"
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld"
    -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld -Wl,-Bsymbolic"
    -DCMAKE_MODULE_LINKER_FLAGS="-fuse-ld=lld -Wl,-Bsymbolic"
    -DCMAKE_AR="${LLVM_BIN}/llvm-ar"
    -DCMAKE_RANLIB="${LLVM_BIN}/llvm-ranlib"
    -DCMAKE_NM="${LLVM_BIN}/llvm-nm"
  )

  cmake "${tgt_opts[@]}" || return 1

  ninja -j$(nproc) || ninja
}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  local SDOJ_PORT_DIR="${INSTALL}/storage/roms/ports/sdoj"
  mkdir -p "${SDOJ_PORT_DIR}"

  if [ -f "${PKG_BUILD}/.${TARGET_NAME}/SDOJ-Recomp" ]; then
    cp -v "${PKG_BUILD}/.${TARGET_NAME}/SDOJ-Recomp" "${SDOJ_PORT_DIR}/sdoj-recomp"
  elif [ -f "${PKG_BUILD}/.${TARGET_NAME}/sdoj-recomp" ]; then
    cp -v "${PKG_BUILD}/.${TARGET_NAME}/sdoj-recomp" "${SDOJ_PORT_DIR}/sdoj-recomp"
  elif [ -f "${PKG_BUILD}/.${TARGET_NAME}/saidaioujou_recomp_tu1" ]; then
    cp -v "${PKG_BUILD}/.${TARGET_NAME}/saidaioujou_recomp_tu1" "${SDOJ_PORT_DIR}/sdoj-recomp"
  else
    echo "Missing SDOJ executable in ${PKG_BUILD}/.${TARGET_NAME}" >&2
    return 1
  fi

  # Keep the executable and all private libraries together in the writable
  # port directory (/roms is a symlink to /storage/roms on ROCKNIX).
  find "${PKG_BUILD}/.${TARGET_NAME}" -maxdepth 1 -name "libsaidaioujou_recomp_tu1_*.so" \
    -exec cp -v {} "${SDOJ_PORT_DIR}/" \;

  # ReXGlue emits its runtime beside the SDK rather than in the target build
  # directory. Both libraries are direct dependencies of the executable.
  local REX_RUNTIME_DIR="${PKG_BUILD}/thirdparty/rexglue-sdk/out/linux-arm64"
  for _library in librexruntime.so libTracyClient.so; do
    if [ ! -f "${REX_RUNTIME_DIR}/${_library}" ]; then
      echo "Missing required ReXGlue runtime: ${REX_RUNTIME_DIR}/${_library}" >&2
      return 1
    fi
    cp -v "${REX_RUNTIME_DIR}/${_library}" "${SDOJ_PORT_DIR}/"
  done

  chmod 755 "${SDOJ_PORT_DIR}/sdoj-recomp"

  if [ -d "${PKG_DIR}/scripts" ]; then
    cp -rf ${PKG_DIR}/scripts/* ${INSTALL}/usr/bin/
  fi
  chmod 755 ${INSTALL}/usr/bin/*
}
