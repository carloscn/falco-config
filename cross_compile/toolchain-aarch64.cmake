# CMake Toolchain File for TI J721E ARM64 Cross-Compilation
# Target: aarch64-none-linux-gnu
# Sysroot: TI Processor SDK Linux ADAS J721E

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Sysroot path
set(SYSROOT "/opt/ti-processor-sdk-linux-adas-j721e-evm-09_02_00_05/linux-devkit/sysroots/aarch64-oe-linux")

# Cross-compiler paths
set(CROSS_COMPILE_PREFIX "/opt/cross-compile/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu")
set(CROSS_COMPILE_TRIPLE "aarch64-none-linux-gnu")

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
set(PKG_CONFIG_EXECUTABLE "/usr/bin/pkg-config")
