#!/usr/bin/env bash
# Falco Installation and Configuration Script
# For Ubuntu 22.04 Docker container
# Supports: stable, latest, compile installation methods
# Note: This script requires root or sudo privileges

set -e

# Avoid interactive prompts during apt/dpkg (critical for Docker non-interactive runs)
export DEBIAN_FRONTEND=noninteractive

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    if ! sudo -n true 2>/dev/null; then
        echo "Error: This script requires root or sudo privileges"
        echo "Please run with: sudo $0"
        exit 1
    fi
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# Installation options
INSTALL_METHOD="${1:-stable}"  # stable: official package, latest: latest version, compile: from source
FALCO_VERSION="${2:-}"         # Specific version (optional)

echo "=========================================="
echo "Falco Installation and Configuration Script"
echo "=========================================="
echo "Installation method: $INSTALL_METHOD"
if [ -n "$FALCO_VERSION" ]; then
    echo "Specified version: $FALCO_VERSION"
fi
echo "=========================================="
echo ""

# ============================================
# Step 1: Update system and install dependencies
# ============================================
echo "[1/5] Update system and install dependencies..."
$SUDO_CMD apt-get update

echo "Installing required packages..."
$SUDO_CMD apt-get install -y \
    curl \
    apt-transport-https \
    gnupg \
    lsb-release \
    dkms \
    make \
    linux-headers-$(uname -r) \
    clang \
    llvm \
    dialog \
    jq \
    wget \
    git \
    cmake \
    build-essential \
    libelf-dev \
    sudo \
    || echo "Warning: Some packages may already be installed or failed, continuing..."

# ============================================
# Step 2: Configure GPG key and repository (for package installation only)
# ============================================
if [ "$INSTALL_METHOD" != "compile" ]; then
    echo ""
    echo "[2/5] Configure Falco GPG key and repository..."
    
    # Clean old configuration
    $SUDO_CMD rm -f /usr/share/keyrings/falco-archive-keyring.gpg
    $SUDO_CMD rm -f /etc/apt/sources.list.d/falcosecurity.list
    $SUDO_CMD mkdir -p /usr/share/keyrings
    
    # Download and import GPG key
    KEY_URL="https://falco.org/repo/falcosecurity-packages.asc"
    KEYRING_PATH="/usr/share/keyrings/falco-archive-keyring.gpg"
    
    echo "Downloading GPG key..."
    MAX_RETRIES=3
    RETRY_COUNT=0
    DOWNLOAD_SUCCESS=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "  Attempting download ($RETRY_COUNT/$MAX_RETRIES)..."
        
        if curl -fsSL "$KEY_URL" -o /tmp/falco-gpg.asc 2>/dev/null; then
            if [ -s /tmp/falco-gpg.asc ] && head -1 /tmp/falco-gpg.asc | grep -q "BEGIN PGP"; then
                echo "  Download successful, importing key..."
                $SUDO_CMD gpg --dearmor -o "$KEYRING_PATH" /tmp/falco-gpg.asc
                rm -f /tmp/falco-gpg.asc
                DOWNLOAD_SUCCESS=true
                break
            else
                echo "  Downloaded file is invalid, retrying..."
                rm -f /tmp/falco-gpg.asc
            fi
        else
            echo "  Download failed, retrying..."
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                sleep 2
            fi
        fi
    done
    
    if [ "$DOWNLOAD_SUCCESS" = false ] || [ ! -f "$KEYRING_PATH" ] || [ ! -s "$KEYRING_PATH" ]; then
        echo "Error: GPG key file creation failed or is empty"
        exit 1
    fi
    
    $SUDO_CMD chmod 644 "$KEYRING_PATH"
    echo "??GPG key added and verified"
    
    # Add Falco repository
    echo "Adding Falco repository..."
    echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
        | $SUDO_CMD tee /etc/apt/sources.list.d/falcosecurity.list > /dev/null
    echo "??Repository added"
    
    # Update package list
    echo "Updating package list..."
    $SUDO_CMD apt-get update
fi

# ============================================
# Step 3: Install Falco
# ============================================
echo ""
echo "[3/5] Install Falco..."

export DEBIAN_FRONTEND=noninteractive
export FALCO_DRIVER_CHOICE=modern_ebpf

if [ "$INSTALL_METHOD" = "compile" ]; then
    echo "Compiling Falco from source..."
    
    # Determine version
    if [ -z "$FALCO_VERSION" ]; then
        # Get latest version
        FALCO_VERSION=$(curl -s https://api.github.com/repos/falcosecurity/falco/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
        echo "Detected latest version: $FALCO_VERSION"
    fi
    
    # Download source
    COMPILE_DIR="/tmp/falco-compile-${FALCO_VERSION}"
    mkdir -p "$COMPILE_DIR"
    cd "$COMPILE_DIR"
    
    if [ ! -d "falco-${FALCO_VERSION}" ]; then
        echo "Downloading Falco source v${FALCO_VERSION}..."
        wget -q "https://github.com/falcosecurity/falco/archive/refs/tags/${FALCO_VERSION}.tar.gz" -O falco-${FALCO_VERSION}.tar.gz 2>/dev/null || \
        wget -q "https://github.com/falcosecurity/falco/archive/refs/tags/v${FALCO_VERSION}.tar.gz" -O falco-${FALCO_VERSION}.tar.gz 2>/dev/null
        
        if [ ! -f falco-${FALCO_VERSION}.tar.gz ]; then
            echo "Error: Unable to download Falco source"
            exit 1
        fi
        
        tar -xzf falco-${FALCO_VERSION}.tar.gz
        rm -f falco-${FALCO_VERSION}.tar.gz
    fi
    
    cd falco-${FALCO_VERSION} || cd falco-*
    
    # Compile
    echo "Starting Falco compilation (this may take some time)..."
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DFALCO_ETC_DIR=/etc/falco \
          -DDRIVER_VERSION=${FALCO_VERSION} \
          ..
    make -j$(nproc)
    make install
    
    echo "??Falco compilation and installation completed"
    
elif [ "$INSTALL_METHOD" = "latest" ]; then
    echo "Installing latest version of Falco..."
    $SUDO_CMD apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" falco
    
elif [ -n "$FALCO_VERSION" ]; then
    echo "Installing specified version: falco=${FALCO_VERSION}..."
    $SUDO_CMD apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" falco=${FALCO_VERSION} || {
        echo "Warning: Specified version installation failed, trying latest stable..."
        $SUDO_CMD apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" falco
    }
else
    echo "Installing stable version of Falco..."
    $SUDO_CMD apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" falco || {
        echo "Warning: modern eBPF driver installation failed, trying kernel module driver..."
        export FALCO_DRIVER_CHOICE=kmod
        $SUDO_CMD apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" falco
    }
fi

# Check Falco version
echo ""
echo "Falco installation info:"
falco --version || echo "Warning: Falco command not available"

# ============================================
# Step 4: Configure Falco
# ============================================
echo ""
echo "[4/5] Configure Falco..."

# Configure Falco log output
FALCO_CONFIG="/etc/falco/falco.yaml"
if [ -f "$FALCO_CONFIG" ]; then
    if [ ! -f "${FALCO_CONFIG}.backup" ]; then
        $SUDO_CMD cp "$FALCO_CONFIG" "${FALCO_CONFIG}.backup"
    fi
    
    # Enable file_output (output to file)
    if $SUDO_CMD grep -q "^file_output:" "$FALCO_CONFIG"; then
        # Enable file_output and set correct filename
        $SUDO_CMD sed -i '/^file_output:/,/^[[:space:]]*[a-z_]*output:/ {
            /enabled:/s/enabled:.*/enabled: true/
            /filename:/s|filename:.*|filename: /var/log/falco.log|
        }' "$FALCO_CONFIG"
        echo "??Enabled file_output (output to /var/log/falco.log)"
    else
        # If file_output doesn't exist, add configuration
        if $SUDO_CMD grep -q "^# \[Stable\] \`file_output\`" "$FALCO_CONFIG"; then
            $SUDO_CMD sed -i '/^# \[Stable\] \`file_output\`/a file_output:\n  enabled: true\n  filename: /var/log/falco.log' "$FALCO_CONFIG"
            echo "??Added file_output configuration"
        fi
    fi
    
    echo "??Falco configuration file: $FALCO_CONFIG"
else
    echo "Warning: Falco configuration file does not exist"
fi

# Create local rules file (if not exists)
LOCAL_RULES="/etc/falco/falco_rules.local.yaml"
if [ ! -f "$LOCAL_RULES" ]; then
    $SUDO_CMD touch "$LOCAL_RULES"
    echo "# Custom Falco rules" | $SUDO_CMD tee "$LOCAL_RULES" > /dev/null
    echo "# Add custom rules here, will not be overwritten by Falco upgrades" | $SUDO_CMD tee -a "$LOCAL_RULES" > /dev/null
    echo "??Created local rules file: $LOCAL_RULES"
fi

# Ensure load_plugins is empty (don't load any plugins, avoid container plugin issues)
FALCO_MAIN_CONFIG="/etc/falco/falco.yaml"
if [ -f "$FALCO_MAIN_CONFIG" ]; then
    if $SUDO_CMD grep -q "^load_plugins:" "$FALCO_MAIN_CONFIG"; then
        $SUDO_CMD sed -i 's/^load_plugins:.*/load_plugins: []/' "$FALCO_MAIN_CONFIG"
        echo "??Ensured load_plugins is empty list (no plugins loaded)"
    fi
fi

# Critical: Delete container plugin configuration file in config.d
# Falco 0.42+ has container functionality as built-in bundled plugin, auto-loaded
# If container plugin is specified in config.d, it will cause duplicate loading conflict
CONTAINER_PLUGIN_CONFIG="/etc/falco/config.d/falco.container_plugin.yaml"
if [ -f "$CONTAINER_PLUGIN_CONFIG" ]; then
    echo "Deleting container plugin config file in config.d (Falco 0.42+ has built-in container functionality)..."
    # Backup then delete
    if [ ! -f "${CONTAINER_PLUGIN_CONFIG}.backup" ]; then
        $SUDO_CMD cp "$CONTAINER_PLUGIN_CONFIG" "${CONTAINER_PLUGIN_CONFIG}.backup" 2>/dev/null || true
    fi
    $SUDO_CMD rm -f "$CONTAINER_PLUGIN_CONFIG"
    echo "??Deleted container plugin config file (avoid conflict with built-in plugin)"
fi

# Also delete any existing backup files
$SUDO_CMD rm -f "${CONTAINER_PLUGIN_CONFIG}.backup" 2>/dev/null || true
$SUDO_CMD rm -f "${CONTAINER_PLUGIN_CONFIG}.disabled" 2>/dev/null || true

# Check config.d directory for other container-related configurations
CONFIG_D_DIR="/etc/falco/config.d"
if [ -d "$CONFIG_D_DIR" ]; then
    for config_file in "$CONFIG_D_DIR"/*container*; do
        if [ -f "$config_file" ]; then
            echo "Warning: Found other container-related config: $config_file"
            echo "  Recommend deleting to avoid conflicts"
        fi
    done
fi

# ============================================
# Step 5: Configure LD_PRELOAD (optional, for container plugin symbol issues)
# ============================================
echo ""
echo "[5/5] Configure LD_PRELOAD (optional, for container plugin symbol issues)..."
echo "Note: If container plugin config in config.d is deleted, LD_PRELOAD may not be needed"

# Find libresolv.so path
LIBRESOLV_PATH=""
for path in /lib/x86_64-linux-gnu/libresolv.so.2 /lib64/libresolv.so.2 /usr/lib/x86_64-linux-gnu/libresolv.so.2; do
    if [ -f "$path" ]; then
        LIBRESOLV_PATH="$path"
        break
    fi
done

if [ -n "$LIBRESOLV_PATH" ]; then
    echo "Found libresolv.so: $LIBRESOLV_PATH"
    
    # Create wrapper script
    FALCO_WRAPPER="/usr/local/bin/falco-wrapper.sh"
    $SUDO_CMD tee "$FALCO_WRAPPER" > /dev/null << EOF
#!/bin/bash
# Falco wrapper script using LD_PRELOAD to resolve container plugin symbol issues
export LD_PRELOAD="$LIBRESOLV_PATH"
exec /usr/bin/falco "\$@"
EOF
    $SUDO_CMD chmod +x "$FALCO_WRAPPER"
    echo "??Created Falco wrapper script: $FALCO_WRAPPER"
    
    # Add to tester user's .bashrc (optional)
    if [ -f /home/tester/.bashrc ]; then
        if ! grep -q "LD_PRELOAD.*libresolv" /home/tester/.bashrc; then
            echo "" >> /home/tester/.bashrc
            echo "# Falco LD_PRELOAD configuration (for container plugin symbol issues)" >> /home/tester/.bashrc
            echo "export LD_PRELOAD=\"$LIBRESOLV_PATH\"" >> /home/tester/.bashrc
            echo "??Added to .bashrc"
        fi
    fi
    
    echo ""
    echo "Usage:"
    echo "  Method 1: Use wrapper script"
    echo "    $FALCO_WRAPPER"
    echo ""
    echo "  Method 2: Use environment variable"
    echo "    LD_PRELOAD=$LIBRESOLV_PATH falco"
    echo ""
    echo "  Method 3: Export environment variable then run directly"
    echo "    export LD_PRELOAD=$LIBRESOLV_PATH"
    echo "    falco"
else
    echo "Warning: libresolv.so not found, please find manually:"
    echo "  find /lib* -name libresolv.so*"
fi

# ============================================
# Completion
# ============================================
echo ""
echo "=========================================="
echo "Falco installation and configuration completed!"
echo "=========================================="
echo ""
echo "Installation summary:"
echo "  - Falco version: $(falco --version 2>/dev/null | head -1 || echo 'Unknown')"
echo "  - Configuration file: $FALCO_CONFIG"
echo "  - Local rules: $LOCAL_RULES"
echo "  - Plugin loading: Disabled (load_plugins: [])"
echo "  - Container plugin config: Deleted (Falco 0.42+ has built-in container functionality, avoid duplicate loading)"
if [ -n "$LIBRESOLV_PATH" ]; then
    echo "  - LD_PRELOAD: $LIBRESOLV_PATH (optional)"
fi
echo ""
echo "Next steps:"
echo "  1. Test configuration:"
if [ -n "$LIBRESOLV_PATH" ]; then
    echo "     LD_PRELOAD=$LIBRESOLV_PATH falco --dry-run -c /etc/falco/falco.yaml"
    echo "     or: $FALCO_WRAPPER --dry-run -c /etc/falco/falco.yaml"
else
    echo "     falco --dry-run -c /etc/falco/falco.yaml"
fi
echo "  2. View rules: falco -L"
echo "  3. Start Falco (recommended):"
if [ -n "$LIBRESOLV_PATH" ]; then
    echo "     LD_PRELOAD=$LIBRESOLV_PATH falco -c /etc/falco/falco.yaml &"
    echo "     or: $FALCO_WRAPPER -c /etc/falco/falco.yaml &"
else
    echo "     falco -c /etc/falco/falco.yaml &"
fi
echo "  4. View logs (file_output enabled, view file directly):"
echo "     tail -f /var/log/falco.log"
echo "  5. Run test cases to trigger events:"
echo "     cd /opt/falco-test"
echo "     bash cases/case1_sensitive_file_opening.sh"
echo ""
echo "Usage:"
echo "  - Default install stable: /tmp/install_falco.sh"
echo "  - Install latest: /tmp/install_falco.sh latest"
echo "  - Compile from source: /tmp/install_falco.sh compile [version]"
echo "  - Install specific version: /tmp/install_falco.sh stable 0.42.0"
echo ""
