#!/bin/bash
#
# Falco Cross-Compilation Build Script
# Target: TI J721E (aarch64)
# 
# Usage: ./build_falco.sh [clean|configure|build|install|all]
#   clean     - Clean all build artifacts
#   configure - Configure CMake only
#   build     - Build only (requires configure first)
#   install   - Install to install directory
#   all       - Full build (default)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
INSTALL_DIR="${SCRIPT_DIR}/install"
SRC_DIR="${SCRIPT_DIR}/src"
PATCHES_DIR="${SCRIPT_DIR}/patches"

# Toolchain settings
SYSROOT="/opt/ti-processor-sdk-linux-adas-j721e-evm-09_02_00_05/linux-devkit/sysroots/aarch64-oe-linux"
CROSS_PREFIX="/opt/cross-compile/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu"
CROSS_TRIPLE="aarch64-none-linux-gnu"
TOOLCHAIN_FILE="${SCRIPT_DIR}/toolchain-aarch64.cmake"

# Export cross-compiler environment
export CC="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-gcc"
export CXX="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-g++"
export AR="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-ar"
export RANLIB="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-ranlib"
export STRIP="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-strip"
export LD="${CROSS_PREFIX}/bin/${CROSS_TRIPLE}-ld"
export PATH="${CROSS_PREFIX}/bin:${PATH}"

# Number of parallel jobs
JOBS=$(nproc)

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [[ ! -d "${SYSROOT}" ]]; then
        log_error "Sysroot not found: ${SYSROOT}"
        exit 1
    fi
    
    if [[ ! -f "${CC}" ]]; then
        log_error "Cross-compiler not found: ${CC}"
        exit 1
    fi
    
    for cmd in cmake git make wget; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is required but not installed"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Create directories
create_dirs() {
    log_info "Creating build directories..."
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"/{lib,include,bin}
    mkdir -p "${SRC_DIR}"
    mkdir -p "${PATCHES_DIR}"
}

# Clone or update Falco
clone_falco() {
    log_info "Cloning/updating Falco source..."
    
    if [[ -d "${SRC_DIR}/falco" ]]; then
        log_info "Falco source exists, updating..."
        cd "${SRC_DIR}/falco"
        git fetch --tags
    else
        cd "${SRC_DIR}"
        git clone --depth 1 https://github.com/falcosecurity/falco.git
    fi
    
    # Initialize submodules
    cd "${SRC_DIR}/falco"
    git submodule update --init --recursive
    
    log_success "Falco source ready"
}

# Apply cross-compilation patches to libs cmake modules
apply_patches() {
    log_info "Applying cross-compilation patches..."
    
    local LIBS_CMAKE="${BUILD_DIR}/falco/falcosecurity-libs-repo/falcosecurity-libs-prefix/src/falcosecurity-libs/cmake/modules"
    
    if [[ ! -d "${LIBS_CMAKE}" ]]; then
        log_warning "Libs cmake modules not found yet, patches will be applied after CMake configure"
        return
    fi
    
    # Patch tbb.cmake
    if [[ -f "${LIBS_CMAKE}/tbb.cmake" ]]; then
        if ! grep -q "CMAKE_SYSTEM_PROCESSOR" "${LIBS_CMAKE}/tbb.cmake"; then
            log_info "Patching tbb.cmake for cross-compilation..."
            sed -i 's/-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}/-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}\n\t\t\t\t\t\t   -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}\n\t\t\t\t\t\t   -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}\n\t\t\t\t\t\t   -DCMAKE_SYSROOT=${CMAKE_SYSROOT}/g' "${LIBS_CMAKE}/tbb.cmake"
        fi
    fi
    
    # Patch zlib.cmake
    if [[ -f "${LIBS_CMAKE}/zlib.cmake" ]]; then
        if ! grep -q 'env "CC=\${CMAKE_C_COMPILER}"' "${LIBS_CMAKE}/zlib.cmake"; then
            log_info "Patching zlib.cmake for cross-compilation..."
            sed -i 's/CONFIGURE_COMMAND env "CFLAGS=\${ZLIB_CFLAGS}"/CONFIGURE_COMMAND env "CC=${CMAKE_C_COMPILER}" "AR=${CMAKE_AR}" "RANLIB=${CMAKE_RANLIB}" "CFLAGS=${ZLIB_CFLAGS} --sysroot=${CMAKE_SYSROOT}"/g' "${LIBS_CMAKE}/zlib.cmake"
        fi
    fi
    
    # Patch jsoncpp.cmake
    if [[ -f "${LIBS_CMAKE}/jsoncpp.cmake" ]]; then
        if ! grep -q "CMAKE_SYSTEM_PROCESSOR" "${LIBS_CMAKE}/jsoncpp.cmake"; then
            log_info "Patching jsoncpp.cmake for cross-compilation..."
            sed -i 's/-DCMAKE_INSTALL_LIBDIR=lib$/-DCMAKE_INSTALL_LIBDIR=lib\n\t\t\t\t\t\t   -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}\n\t\t\t\t\t\t   -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}\n\t\t\t\t\t\t   -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}\n\t\t\t\t\t\t   -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}\n\t\t\t\t\t\t   -DCMAKE_SYSROOT=${CMAKE_SYSROOT}/g' "${LIBS_CMAKE}/jsoncpp.cmake"
        fi
    fi
    
    # Patch re2.cmake
    if [[ -f "${LIBS_CMAKE}/re2.cmake" ]]; then
        if ! grep -q "CMAKE_SYSTEM_PROCESSOR" "${LIBS_CMAKE}/re2.cmake"; then
            log_info "Patching re2.cmake for cross-compilation..."
            sed -i 's/-DCMAKE_BUILD_TYPE=\${CMAKE_BUILD_TYPE}$/-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}\n\t\t\t\t\t\t   -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}\n\t\t\t\t\t\t   -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}\n\t\t\t\t\t\t   -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}\n\t\t\t\t\t\t   -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}\n\t\t\t\t\t\t   -DCMAKE_SYSROOT=${CMAKE_SYSROOT}/g' "${LIBS_CMAKE}/re2.cmake"
        fi
    fi
    
    log_success "Patches applied"
}

# Configure Falco
configure_falco() {
    log_info "Configuring Falco with CMake..."
    
    mkdir -p "${BUILD_DIR}/falco"
    cd "${BUILD_DIR}/falco"
    
    cmake "${SRC_DIR}/falco" \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DUSE_BUNDLED_DEPS=ON \
        -DBUILD_DRIVER=OFF \
        -DBUILD_BPF=OFF \
        -DBUILD_LIBSCAP_MODERN_BPF=OFF \
        -DBUILD_FALCO_MODERN_BPF=OFF \
        -DBUILD_LIBSCAP_GVISOR=OFF \
        -DCREATE_TEST_TARGETS=OFF \
        -DMINIMAL_BUILD=ON \
        -DBUILD_FALCO_UNIT_TESTS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        2>&1 | tee "${BUILD_DIR}/falco_cmake.log"
    
    # Apply patches after initial cmake (libs are downloaded during cmake)
    apply_patches
    
    # Reconfigure after patches
    log_info "Reconfiguring after patches..."
    cmake "${SRC_DIR}/falco" \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DUSE_BUNDLED_DEPS=ON \
        -DBUILD_DRIVER=OFF \
        -DBUILD_BPF=OFF \
        -DBUILD_LIBSCAP_MODERN_BPF=OFF \
        -DBUILD_FALCO_MODERN_BPF=OFF \
        -DBUILD_LIBSCAP_GVISOR=OFF \
        -DCREATE_TEST_TARGETS=OFF \
        -DMINIMAL_BUILD=ON \
        -DBUILD_FALCO_UNIT_TESTS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        2>&1 | tee -a "${BUILD_DIR}/falco_cmake.log"
    
    log_success "CMake configuration complete"
}

# Build Falco
build_falco() {
    log_info "Building Falco..."
    
    cd "${BUILD_DIR}/falco"
    
    make -j${JOBS} 2>&1 | tee "${BUILD_DIR}/falco_build.log"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log_success "Falco built successfully!"
    else
        log_error "Falco build failed. Check ${BUILD_DIR}/falco_build.log"
        exit 1
    fi
}

# Install Falco
install_falco() {
    log_info "Installing Falco..."
    
    cd "${BUILD_DIR}/falco"
    make install
    
    # Strip the binary
    log_info "Stripping binary for smaller size..."
    ${STRIP} -s "${INSTALL_DIR}/bin/falco"
    
    local BINARY_SIZE=$(du -h "${INSTALL_DIR}/bin/falco" | cut -f1)
    log_success "Falco installed to ${INSTALL_DIR}/bin/falco (${BINARY_SIZE})"
    
    # Show binary info
    log_info "Binary info:"
    file "${INSTALL_DIR}/bin/falco"
}

# Clean build
clean_build() {
    log_info "Cleaning build directories..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${INSTALL_DIR}"
    log_success "Build directories cleaned"
}

# Full clean (including sources)
full_clean() {
    log_info "Full clean (including sources)..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${INSTALL_DIR}"
    rm -rf "${SRC_DIR}"
    log_success "All directories cleaned"
}

# Show help
show_help() {
    echo "Falco Cross-Compilation Build Script for TI J721E (ARM64)"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  all       - Full build (default)"
    echo "  configure - Configure CMake only"
    echo "  build     - Build only (requires configure)"
    echo "  install   - Install to install directory"
    echo "  clean     - Clean build artifacts"
    echo "  fullclean - Clean everything including sources"
    echo "  help      - Show this help"
    echo ""
    echo "Environment:"
    echo "  SYSROOT: ${SYSROOT}"
    echo "  CROSS:   ${CROSS_PREFIX}"
    echo "  OUTPUT:  ${INSTALL_DIR}/bin/falco"
}

# Main
main() {
    local command="${1:-all}"
    
    case "${command}" in
        all)
            check_prerequisites
            create_dirs
            clone_falco
            configure_falco
            build_falco
            install_falco
            ;;
        configure)
            check_prerequisites
            create_dirs
            clone_falco
            configure_falco
            ;;
        build)
            check_prerequisites
            build_falco
            ;;
        install)
            check_prerequisites
            install_falco
            ;;
        clean)
            clean_build
            ;;
        fullclean)
            full_clean
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
