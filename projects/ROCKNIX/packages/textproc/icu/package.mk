# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2024-present ROCKNIX (https://github.com/ROCKNIX)

. ${ROOT}/packages/addons/addon-depends/icu/package.mk

unset PKG_BUILD_FLAGS

configure_package() {
  PKG_CONFIGURE_SCRIPT="${PKG_BUILD}/source/configure"
  PKG_CONFIGURE_OPTS_HOST="--disable-layout \
                           --disable-layoutex \
                           --enable-renaming \
                           --disable-samples \
                           --disable-tests \
                           --enable-tools \
                           --disable-extras"

  PKG_CONFIGURE_OPTS_TARGET="${PKG_CONFIGURE_OPTS_HOST} \
                             --with-cross-build=${PKG_BUILD}/.${HOST_NAME}"
}


pre_make_host() {
  local icu_host_build="${PKG_BUILD}/.${HOST_NAME}"
  local icu_defs="${icu_host_build}/icudefs.mk"
  local icu_lib_flags="-L${icu_host_build}/lib -L${icu_host_build}/stubdata"

  if [ ! -f "${icu_defs}" ]; then
    echo "ICU host build definitions missing: ${icu_defs}" >&2
    return 1
  fi

  if ! grep -Fq "LDFLAGS = ${icu_lib_flags} " "${icu_defs}"; then
    grep -q '^LDFLAGS = ' "${icu_defs}" || return 1
    sed -i "s|^LDFLAGS = |LDFLAGS = ${icu_lib_flags} |" "${icu_defs}"
  fi

  export LD_LIBRARY_PATH="${icu_host_build}/lib:${icu_host_build}/stubdata${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
}
