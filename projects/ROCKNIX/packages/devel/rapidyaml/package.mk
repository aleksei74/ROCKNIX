# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026-present ROCKNIX (https://github.com/ROCKNIX)

PKG_NAME="rapidyaml"
PKG_VERSION="0.12.1"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/biojppm/rapidyaml"
PKG_URL="${PKG_SITE}/releases/download/v${PKG_VERSION}/rapidyaml-${PKG_VERSION}-src.tgz"
PKG_LONGDESC="A fast YAML parser and emitter for C++."
PKG_DEPENDS_TARGET="toolchain"
PKG_TOOLCHAIN="cmake"
PKG_BUILD_FLAGS="+pic"

PKG_CMAKE_OPTS_TARGET="-DCMAKE_BUILD_TYPE=Release \
                        -DBUILD_SHARED_LIBS=OFF \
                        -DRYML_INSTALL=ON \
                        -DRYML_BUILD_TESTS=OFF \
                        -DRYML_BUILD_BENCHMARKS=OFF \
                        -DRYML_BUILD_TOOLS=OFF \
                        -DRYML_BUILD_API=OFF"
