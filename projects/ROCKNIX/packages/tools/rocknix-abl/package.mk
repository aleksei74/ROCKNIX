# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025 ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="rocknix-abl"
PKG_VERSION="1d6c948b84c8a2030862d3c5443b0fb3b22eab05"
PKG_ARCH="aarch64"
PKG_SITE="https://github.com/ROCKNIX/abl"
PKG_URL="https://github.com/ROCKNIX/abl/archive/${PKG_VERSION}.tar.gz"
PKG_LONGDESC="ROCKNIX ABL."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/share/bootloader/rocknix_abl
    cp ${PKG_BUILD}/abl_signed-${DEVICE}.elf ${INSTALL}/usr/share/bootloader/rocknix_abl/abl_signed.elf
    cp ${PKG_DIR}/sources/* ${INSTALL}/usr/share/bootloader/rocknix_abl

}
