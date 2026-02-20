# Falco Cross-Compilation for TI J721E (ARM64)

This directory contains scripts for cross-compiling Falco for the TI J721E platform.

## Target Platform

- **Architecture**: ARM64 (aarch64)
- **Sysroot**: TI Processor SDK Linux ADAS J721E EVM 09.02.00.05
- **Compiler**: GCC ARM 11.2 (aarch64-none-linux-gnu)
- **Falco Version**: Latest from GitHub

## Prerequisites

Ensure the following are installed on your host system:

- CMake 3.16+
- Git
- Make
- wget

The following paths must exist:
- Sysroot: `/opt/ti-processor-sdk-linux-adas-j721e-evm-09_02_00_05/linux-devkit/sysroots/aarch64-oe-linux`
- Cross-compiler: `/opt/cross-compile/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu/bin`

## Quick Start

```bash
# Make build script executable
chmod +x build_falco.sh

# Build everything (clone, configure, build, install)
./build_falco.sh all
```

The build script automatically:
1. Clones Falco source from GitHub
2. Applies necessary patches for cross-compilation
3. Configures CMake with toolchain file
4. Builds all bundled dependencies for ARM64
5. Compiles Falco
6. Strips the binary for smaller size

## Directory Structure

After building:

```
cross_compile/
├── build_falco.sh          # Main build script
├── toolchain-aarch64.cmake # CMake toolchain file
├── env.sh                  # Environment setup (for manual builds)
├── README.md               # This file
├── src/                    # Source code (auto-downloaded)
│   └── falco/              # Falco source
├── build/                  # Build artifacts
│   └── falco/              # Falco build (includes bundled deps)
└── install/                # Installation prefix
    ├── bin/
    │   └── falco           # Falco executable (~5.6MB stripped)
    ├── lib/                # Libraries
    ├── etc/                # Configuration files
    └── share/              # Rules files
```

## Build Commands

| Command | Description |
|---------|-------------|
| `./build_falco.sh all` | Full build (default) |
| `./build_falco.sh configure` | Configure CMake only |
| `./build_falco.sh build` | Build only (requires configure) |
| `./build_falco.sh install` | Install to install directory |
| `./build_falco.sh clean` | Clean build artifacts |
| `./build_falco.sh fullclean` | Clean everything including sources |
| `./build_falco.sh help` | Show help |

## Manual CMake Usage

For manual builds, source the environment first:

```bash
source env.sh

# Then use CMake with toolchain file
cmake -DCMAKE_TOOLCHAIN_FILE=toolchain-aarch64.cmake ...
```

## Build Output

After successful build:
- Binary: `install/bin/falco` (~5.6MB stripped)
- Configuration: `install/etc/falco/`
- Rules: `install/share/falco/`

## Deployment to Target

Copy the compiled files to the target device:

```bash
# Copy Falco binary
scp install/bin/falco target:/usr/local/bin/

# Copy configuration
scp -r install/etc/falco target:/etc/

# Copy rules
scp -r install/share/falco target:/usr/share/
```

## Cross-Compilation Patches

The build script automatically applies patches to the following bundled dependency cmake modules:
- `tbb.cmake` - Pass CMAKE_SYSTEM_NAME/PROCESSOR/SYSROOT
- `zlib.cmake` - Use cross-compiler CC/AR/RANLIB
- `jsoncpp.cmake` - Pass cross-compilation parameters
- `re2.cmake` - Pass cross-compilation parameters

## Troubleshooting

### Missing sysroot libraries

If build fails due to missing libraries, check if they exist in the sysroot:

```bash
ls /opt/ti-processor-sdk-linux-adas-j721e-evm-09_02_00_05/linux-devkit/sysroots/aarch64-oe-linux/usr/lib/
```

### Build fails with x86 errors

Ensure all bundled dependencies are being built with cross-compilation flags. Check the build logs in `build/` directory.

### Linker errors about ELF format

This usually means some dependency was built for x86 instead of ARM64. Clean and rebuild:
```bash
./build_falco.sh fullclean
./build_falco.sh all
```

## Build Configuration

The Falco build uses the following configuration:
- `MINIMAL_BUILD=ON` - Minimal build to reduce dependencies
- `BUILD_DRIVER=OFF` - No kernel module (requires kernel source)
- `BUILD_BPF=OFF` - No BPF probe
- `BUILD_FALCO_MODERN_BPF=OFF` - No modern BPF
- `USE_BUNDLED_DEPS=ON` - Use bundled dependencies for ARM64

## Notes

- The binary is dynamically linked against glibc from the sysroot
- Kernel module/BPF driver is disabled (requires separate kernel build)
- This builds the userspace components only
- The stripped binary is ~5.6MB
