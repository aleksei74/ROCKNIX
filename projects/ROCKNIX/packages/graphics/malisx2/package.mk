# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="malisx2"
PKG_VERSION="0.5.0"
PKG_SHA256="7e31c5fd431407ccd6d4b1b98206aa5d1455d26befb08b4f1f3a1c1379526a27"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/bmdhacks/malisx2"
PKG_URL="${PKG_SITE}/releases/download/v${PKG_VERSION}/malisx2-${PKG_VERSION}-aarch64.tar.gz"
PKG_SOURCE_DIR="malisx2/${PKG_VERSION}"
PKG_DEPENDS_TARGET="toolchain libdrm mesa vulkan-wsi-layer"
PKG_LONGDESC="Experimental Mali kbase Vulkan ICD for ARMSX2, hakuX and Keisho."
PKG_TOOLCHAIN="manual"
PKG_BUILD_FLAGS="-strip"

MALISX2_DIR="/usr/share/malisx2/${PKG_VERSION}"

makeinstall_target() {
  install -Dm755 "${PKG_BUILD}/libvulkan_malisx2.so" "${INSTALL}${MALISX2_DIR}/libvulkan_malisx2.so"
  sed "s#/storage/malisx2/${PKG_VERSION}#${MALISX2_DIR}#g" \
    "${PKG_BUILD}/malisx2_icd.aarch64.json" > "${INSTALL}${MALISX2_DIR}/malisx2_icd.aarch64.json"
  install -Dm644 "${PKG_BUILD}/MANIFEST.json" "${INSTALL}${MALISX2_DIR}/MANIFEST.json"
  install -Dm755 "${PKG_DIR}/sources/malisx2-env.sh" "${INSTALL}/usr/share/malisx2/malisx2-env.sh"
}
