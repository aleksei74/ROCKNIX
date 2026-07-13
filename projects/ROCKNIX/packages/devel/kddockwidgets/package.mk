# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="kddockwidgets"
PKG_VERSION="2.4.0"
PKG_LICENSE="GPL-2.0-only OR GPL-3.0-only"
PKG_SITE="https://github.com/KDAB/KDDockWidgets"
PKG_URL="${PKG_SITE}/archive/refs/tags/v${PKG_VERSION}.tar.gz"
PKG_LONGDESC="An advanced docking system for Qt."
PKG_DEPENDS_TARGET="toolchain qt6"
PKG_TOOLCHAIN="cmake"

PKG_CMAKE_OPTS_TARGET="-DCMAKE_BUILD_TYPE=Release \
                        -DKDDockWidgets_QT6=ON \
                        -DKDDockWidgets_STATIC=OFF \
                        -DKDDockWidgets_FRONTENDS=qtwidgets \
                        -DKDDockWidgets_NO_SPDLOG=ON \
                        -DKDDockWidgets_EXAMPLES=OFF \
                        -DKDDockWidgets_TESTS=OFF \
                        -DKDDockWidgets_DOCS=OFF \
                        -DKDDockWidgets_PYTHON_BINDINGS=OFF"
