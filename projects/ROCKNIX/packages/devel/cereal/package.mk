PKG_NAME="cereal"
PKG_VERSION="1.3.2"
PKG_SHA256="16a7ad9b31ba5880dac55d62b5d6f243c3ebc8d46a3514149e56b5e7ea81f85f"
PKG_LICENSE="BSD"
PKG_SITE="https://uscilab.github.io/cereal/"
PKG_URL="https://github.com/USCiLab/cereal/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="A header-only C++11 serialization library."
PKG_TOOLCHAIN="cmake"

PKG_CMAKE_OPTS_TARGET="-DBUILD_DOC=OFF \
                       -DBUILD_SANDBOX=OFF \
                       -DJUST_INSTALL_CEREAL=ON"