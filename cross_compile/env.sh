#!/bin/bash
#
# Environment Setup Script for Falco Cross-Compilation
# Source this file before running manual commands:
#   source env.sh

# Sysroot
export SYSROOT="/opt/ti-processor-sdk-linux-adas-j721e-evm-09_02_00_05/linux-devkit/sysroots/aarch64-oe-linux"

# Cross-compiler
export CROSS_PREFIX="/opt/cross-compile/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu"
export CROSS_TRIPLE="aarch64-none-linux-gnu"

# Tools
export CC="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-gcc"
export CXX="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-g++"
export AR="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-ar"
export RANLIB="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-ranlib"
export STRIP="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-strip"
export LD="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-ld"
export NM="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-nm"
export OBJCOPY="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-objcopy"
export OBJDUMP="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-objdump"

# Add cross-compiler to PATH
export PATH="${CROSS_PREFIX}/bin:${PATH}"

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INSTALL_DIR="${SCRIPT_DIR}/install"

# Compiler flags
export CFLAGS="--sysroot=${SYSROOT} -I${SYSROOT}/usr/include -I${INSTALL_DIR}/include"
export CXXFLAGS="--sysroot=${SYSROOT} -I${SYSROOT}/usr/include -I${INSTALL_DIR}/include"
export LDFLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib -L${SYSROOT}/lib -L${INSTALL_DIR}/lib"

# pkg-config
export PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${INSTALL_DIR}/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"

echo "Cross-compilation environment configured for ${CROSS_TRIPLE}"
echo "  SYSROOT: ${SYSROOT}"
echo "  CC: ${CC}"
echo "  CXX: ${CXX}"
