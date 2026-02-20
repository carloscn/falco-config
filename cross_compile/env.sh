#!/bin/bash
#
# Environment Setup Script for Falco Cross-Compilation
# Source this file before running manual commands:
#   source env.sh
#
# Configuration is loaded from build.cfg

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/build.cfg"

# Load configuration from build.cfg
if [[ -f "${CONFIG_FILE}" ]]; then
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        # Remove leading/trailing whitespace and quotes
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^["'\'']//;s/["'\'']$//')
        # Export the variable
        if [[ -n "$key" && -n "$value" ]]; then
            export "$key"="$value"
        fi
    done < "${CONFIG_FILE}"
else
    echo "ERROR: Configuration file not found: ${CONFIG_FILE}"
    echo "Please create build.cfg with SYSROOT and CROSS_COMPILE_PREFIX settings."
    return 1
fi

# Validate required configuration
if [[ -z "${SYSROOT}" ]]; then
    echo "ERROR: SYSROOT is not configured in build.cfg"
    return 1
fi

if [[ -z "${CROSS_COMPILE_PREFIX}" ]]; then
    echo "ERROR: CROSS_COMPILE_PREFIX is not configured in build.cfg"
    return 1
fi

if [[ -z "${CROSS_COMPILE_TRIPLE}" ]]; then
    echo "ERROR: CROSS_COMPILE_TRIPLE is not configured in build.cfg"
    return 1
fi

# Export with standardized names (for toolchain.cmake compatibility)
export SYSROOT
export CROSS_PREFIX="${CROSS_COMPILE_PREFIX}"
export CROSS_TRIPLE="${CROSS_COMPILE_TRIPLE}"

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

# Install directory
export INSTALL_DIR="${SCRIPT_DIR}/install"

# Compiler flags
export CFLAGS="--sysroot=${SYSROOT} -I${SYSROOT}/usr/include -I${INSTALL_DIR}/include"
export CXXFLAGS="--sysroot=${SYSROOT} -I${SYSROOT}/usr/include -I${INSTALL_DIR}/include"
export LDFLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib -L${SYSROOT}/lib -L${INSTALL_DIR}/lib"

# pkg-config
export PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig:${INSTALL_DIR}/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"

echo "Cross-compilation environment configured for ${CROSS_TRIPLE}"
echo "  Config:  ${CONFIG_FILE}"
echo "  SYSROOT: ${SYSROOT}"
echo "  CC:      ${CC}"
echo "  CXX:     ${CXX}"
