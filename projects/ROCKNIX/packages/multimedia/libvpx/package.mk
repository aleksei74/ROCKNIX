# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2021-present 351ELEC (https://github.com/351ELEC)
# Copyright (C) 2023 JELOS (https://github.com/JustEnoughLinuxOS)

PKG_NAME="libvpx"
PKG_VERSION="1.16.0"
PKG_SHA256="7a479a3c66b9f5d5542a4c6a1b7d3768a983b1e5c14c60a9396edc9b649e015c"
PKG_LICENSE="BSD-3-Clause"
PKG_SITE="https://github.com/webmproject/libvpx"
PKG_URL="${PKG_SITE}/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_HOST="toolchain nasm:host"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="WebM VP8/VP9 Codec"

configure_host() {
  HOST_ARCH=$(uname -m)

  case ${HOST_ARCH} in
    aarch64)
      PKG_HOST_NAME_LIBVPX="arm64-linux-gcc"
      ;;
    arm)
      PKG_HOST_NAME_LIBVPX="armv7-linux-gcc"
      ;;
    x86_64)
      PKG_HOST_NAME_LIBVPX="x86_64-linux-gcc"
      ;;
  esac

  ${PKG_CONFIGURE_SCRIPT} --prefix=${TOOLCHAIN} \
                          --extra-cflags="${CFLAGS}" \
                          --as=nasm \
                          --target=${PKG_HOST_NAME_LIBVPX} \
                          --disable-docs \
                          --disable-examples \
                          --disable-shared \
                          --disable-tools \
                          --disable-unit-tests \
                          --disable-vp8-decoder \
                          --disable-vp9-decoder \
                          --enable-ccache \
                          --enable-pic \
                          --enable-static \
                          --enable-vp8 \
                          --enable-vp9
}

configure_target() {
  case ${ARCH} in
    aarch64)
      PKG_TARGET_NAME_LIBVPX="arm64-linux-gcc"
      ;;
    arm)
      PKG_TARGET_NAME_LIBVPX="armv7-linux-gcc"
      ;;
    x86_64)
      PKG_TARGET_NAME_LIBVPX="x86_64-linux-gcc"
      ;;
  esac

  ${PKG_CONFIGURE_SCRIPT} --prefix=/usr \
                          --extra-cflags="${CFLAGS}" \
                          --as=nasm \
                          --target=${PKG_TARGET_NAME_LIBVPX} \
                          --disable-docs \
                          --disable-examples \
                          --enable-shared \
                          --disable-tools \
                          --disable-unit-tests \
                          --disable-vp8-decoder \
                          --disable-vp9-decoder \
                          --enable-ccache \
                          --enable-pic \
                          --enable-static \
                          --enable-vp8 \
                          --enable-vp9
}

post_makeinstall_target() {
  local vpx_lib=$(basename "$(readlink -f "${INSTALL}/usr/lib/libvpx.so")")
  [ -f "${INSTALL}/usr/lib/${vpx_lib}" ] || die "libvpx: no installed library to point libvpx.so.6 at"
  ln -sfv "${vpx_lib}" "${INSTALL}/usr/lib/libvpx.so.6"
}


# libvpx's own headers must precede headers installed by an older libvpx
# in the host toolchain or target sysroot. Its generated makefile appends
# the source include directory *after* inherited CFLAGS/CXXFLAGS, which
# otherwise selects stale headers (vpx_codec_enc_init_multi_ver const ABI).
libvpx_source_header_first() {
  local mk flag found=0
  for mk in "${PKG_REAL_BUILD}"/libs-*.mk; do
    [ -f "${mk}" ] || continue
    found=1

    for flag in CFLAGS CXXFLAGS; do
      grep -q "^${flag}[[:space:]]*=" "${mk}" || {
        echo "libvpx: missing ${flag} in ${mk}" >&2
        return 1
      }

      if ! grep -Eq "^${flag}[[:space:]]*=[[:space:]]*-I${PKG_BUILD}([[:space:]]|$)" "${mk}"; then
        sed -i -E "s|^(${flag}[[:space:]]*=[[:space:]]*)|\\1-I${PKG_BUILD} |" "${mk}" || return 1
      fi
    done
  done

  [ "${found}" -eq 1 ] || {
    echo "libvpx: generated libs-*.mk not found in ${PKG_REAL_BUILD}" >&2
    return 1
  }
}

pre_make_host() {
  libvpx_source_header_first
}

pre_make_target() {
  libvpx_source_header_first
}
