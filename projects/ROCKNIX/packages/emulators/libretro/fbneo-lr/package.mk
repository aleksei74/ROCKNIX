# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019-present Shanti Gilbert (https://github.com/shantigilbert)
# Maintenance 2020 351ELEC team (https://github.com/fewtarius/351ELEC)
# Copyright (C) 2023 JELOS (https://github.com/JustEnoughLinuxOS)

PKG_NAME="fbneo-lr"
PKG_VERSION="7e5d732ac1097fdea4439b6af9b8e2bf40ab86df" # DsNo (260817)
PKG_SHA256="d104af1d0e058a127225f29a80c106f5fa5225433f85e607710f7f51ba4039fc"
PKG_LICENSE="Non-commercial"
PKG_SITE="https://github.com/aleksei74/FBNeo"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Port of Final Burn Neo to Libretro (v0.2.97.38)."
PKG_TOOLCHAIN="make"


pre_configure_target() {
sed -i "s|LDFLAGS += -static-libgcc -static-libstdc++|LDFLAGS += -static-libgcc|" "${PKG_BUILD}/src/burner/libretro/Makefile"

PKG_MAKE_OPTS_TARGET=" -C ${PKG_BUILD}/src/burner/libretro USE_CYCLONE=0 profile=performance GIT_VERSION=${PKG_VERSION:0:10}"

if [[ "${TARGET_FPU}" =~ "neon" ]]; then
	PKG_MAKE_OPTS_TARGET+=" HAVE_NEON=1"
fi

}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/libretro
  cp ${PKG_BUILD}/src/burner/libretro/fbneo_libretro.so ${INSTALL}/usr/lib/libretro/
}
