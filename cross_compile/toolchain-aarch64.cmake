# CMake Toolchain File for ARM64 Cross-Compilation
# 
# Configuration is read from environment variables (set by build.cfg via build_falco.sh)
# Required environment variables:
#   - SYSROOT: Path to target sysroot
#   - CROSS_PREFIX or CROSS_COMPILE_PREFIX: Path to cross-compiler toolchain
#   - CROSS_TRIPLE or CROSS_COMPILE_TRIPLE: Cross-compiler target triple

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Read SYSROOT from environment (required)
if(DEFINED ENV{SYSROOT})
    set(SYSROOT "$ENV{SYSROOT}")
else()
    message(FATAL_ERROR "SYSROOT environment variable is not set. Please run via build_falco.sh or source env.sh first.")
endif()

# Read CROSS_PREFIX from environment (required)
if(DEFINED ENV{CROSS_PREFIX})
    set(CROSS_COMPILE_PREFIX "$ENV{CROSS_PREFIX}")
elseif(DEFINED ENV{CROSS_COMPILE_PREFIX})
    set(CROSS_COMPILE_PREFIX "$ENV{CROSS_COMPILE_PREFIX}")
else()
    message(FATAL_ERROR "CROSS_PREFIX or CROSS_COMPILE_PREFIX environment variable is not set. Please run via build_falco.sh or source env.sh first.")
endif()

# Read CROSS_TRIPLE from environment (required)
if(DEFINED ENV{CROSS_TRIPLE})
    set(CROSS_COMPILE_TRIPLE "$ENV{CROSS_TRIPLE}")
elseif(DEFINED ENV{CROSS_COMPILE_TRIPLE})
    set(CROSS_COMPILE_TRIPLE "$ENV{CROSS_COMPILE_TRIPLE}")
else()
    message(FATAL_ERROR "CROSS_TRIPLE or CROSS_COMPILE_TRIPLE environment variable is not set. Please run via build_falco.sh or source env.sh first.")
endif()

# C/C++ compilers
set(CMAKE_C_COMPILER "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-gcc")
set(CMAKE_CXX_COMPILER "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-g++")
set(CMAKE_AR "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-ar")
set(CMAKE_RANLIB "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-ranlib")
set(CMAKE_STRIP "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-strip")
set(CMAKE_LINKER "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-ld")
set(CMAKE_NM "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-nm")
set(CMAKE_OBJCOPY "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-objcopy")
set(CMAKE_OBJDUMP "${CROSS_COMPILE_PREFIX}/bin/${CROSS_COMPILE_TRIPLE}-objdump")

# Sysroot
set(CMAKE_SYSROOT ${SYSROOT})

# Compiler flags
set(CMAKE_C_FLAGS_INIT "--sysroot=${SYSROOT}")
set(CMAKE_CXX_FLAGS_INIT "--sysroot=${SYSROOT}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "--sysroot=${SYSROOT} -L${SYSROOT}/lib -L${SYSROOT}/usr/lib")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "--sysroot=${SYSROOT} -L${SYSROOT}/lib -L${SYSROOT}/usr/lib")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "--sysroot=${SYSROOT} -L${SYSROOT}/lib -L${SYSROOT}/usr/lib")

# Search paths
set(CMAKE_FIND_ROOT_PATH ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Include paths
include_directories(SYSTEM 
    ${SYSROOT}/usr/include
    ${SYSROOT}/include
)

# Library paths
link_directories(
    ${SYSROOT}/usr/lib
    ${SYSROOT}/lib
)

# pkg-config setup
set(ENV{PKG_CONFIG_PATH} "${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${SYSROOT}")

# Print configuration summary
message(STATUS "Cross-compilation toolchain loaded:")
message(STATUS "  SYSROOT: ${SYSROOT}")
message(STATUS "  COMPILER: ${CMAKE_C_COMPILER}")
message(STATUS "  TRIPLE: ${CROSS_COMPILE_TRIPLE}")
