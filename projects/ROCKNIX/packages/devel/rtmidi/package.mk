# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX

PKG_NAME="rtmidi"
PKG_VERSION="6.0.0"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/thestk/rtmidi"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain alsa-lib"
PKG_LONGDESC="RtMidi is a set of C++ classes that provide a common API for realtime MIDI input/output."
PKG_TOOLCHAIN="cmake"

pre_configure_target() {
  PKG_CMAKE_OPTS_TARGET+=" -DCMAKE_BUILD_TYPE=Release \
                           -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
                           -DBUILD_SHARED_LIBS=OFF \
                           -DRTMIDI_BUILD_TESTING=OFF \
                           -DRTMIDI_API_ALSA=ON \
                           -DRTMIDI_API_JACK=OFF \
                           -DRTMIDI_API_WINMM=OFF \
                           -DRTMIDI_API_CORE=OFF \
                           -DRTMIDI_API_AMIDI=OFF"
}
