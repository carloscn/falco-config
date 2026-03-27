#!/usr/bin/env bash
#
# Prepare OTA deployment bundle for readonly rootfs workflow.
# This script collects runtime artifacts into a single folder that can be
# integrated into firmware image/OTA package (no SCP/SSH deployment required).
#
# Usage:
#   ./prepare_ota_bundle.sh
#   ./prepare_ota_bundle.sh --output-dir /tmp/falco_bundle_for_ota
#   ./prepare_ota_bundle.sh --output-dir /tmp/falco_bundle_for_ota --tar
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/cross_compile/install"
OUTPUT_DIR="${SCRIPT_DIR}/falco_bundle_for_ota"
MAKE_TAR=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --tar)
            MAKE_TAR=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--output-dir <dir>] [--tar]"
            exit 0
            ;;
        *)
            echo "[ERR] Unknown argument: $1"
            exit 1
            ;;
    esac
done

echo "[INFO] Preparing OTA bundle at: ${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"/{usr/local/bin,usr/share/falco,etc/falco/config.d,etc/systemd/system,opt/falco-test}

if [[ ! -f "${INSTALL_DIR}/bin/falco" ]]; then
    echo "[ERR] Missing ${INSTALL_DIR}/bin/falco"
    echo "[INFO] Build first: cd cross_compile && ./build_falco.sh all"
    exit 1
fi

# Binaries
cp -f "${INSTALL_DIR}/bin/falco" "${OUTPUT_DIR}/usr/local/bin/falco"
if [[ -f "${INSTALL_DIR}/bin/falcoctl" ]]; then
    cp -f "${INSTALL_DIR}/bin/falcoctl" "${OUTPUT_DIR}/usr/local/bin/falcoctl"
fi
chmod +x "${OUTPUT_DIR}/usr/local/bin/falco"
[[ -f "${OUTPUT_DIR}/usr/local/bin/falcoctl" ]] && chmod +x "${OUTPUT_DIR}/usr/local/bin/falcoctl"

# Core falco files
cp -a "${INSTALL_DIR}/etc/falco/." "${OUTPUT_DIR}/etc/falco/"
cp -a "${INSTALL_DIR}/share/falco/." "${OUTPUT_DIR}/usr/share/falco/"

# Board runtime configs (kmod-only)
cp -f "${SCRIPT_DIR}/config/falco.container_plugin.board.yaml" "${OUTPUT_DIR}/etc/falco/config.d/"
cp -f "${SCRIPT_DIR}/config/falco.json_output.board.yaml" "${OUTPUT_DIR}/etc/falco/config.d/"
cp -f "${REPO_ROOT}/falco-config/falco_rules.local.yaml" "${OUTPUT_DIR}/etc/falco/falco_rules.local.yaml"

# Keep config.d minimal/explicit for deployment team
rm -f "${OUTPUT_DIR}"/etc/falco/config.d/*modern*bpf*.yaml "${OUTPUT_DIR}"/etc/falco/config.d/*modern*ebpf*.yaml || true
rm -f "${OUTPUT_DIR}/etc/falco/config.d/falco.container_plugin.yaml" "${OUTPUT_DIR}/etc/falco/config.d/falco.embedded.board.yaml" || true

# kmod artifact
if [[ -f "${INSTALL_DIR}/share/falco/falco.ko" ]]; then
    cp -f "${INSTALL_DIR}/share/falco/falco.ko" "${OUTPUT_DIR}/usr/share/falco/falco.ko"
else
    echo "[WARN] falco.ko not found. kmod runtime will fail without it."
fi

# Service/startup files
cp -f "${SCRIPT_DIR}/services/falco.service" "${OUTPUT_DIR}/etc/systemd/system/falco.service"
cp -f "${SCRIPT_DIR}/services/falco-start.sh" "${OUTPUT_DIR}/opt/falco-test/falco-start.sh"
cp -f "${SCRIPT_DIR}/services/load-falco-ko.sh" "${OUTPUT_DIR}/opt/falco-test/load-falco-ko.sh"
chmod +x "${OUTPUT_DIR}/opt/falco-test/falco-start.sh" "${OUTPUT_DIR}/opt/falco-test/load-falco-ko.sh"

cat > "${OUTPUT_DIR}/MANIFEST.txt" <<'EOF'
Falco OTA bundle (kmod-only)

Target paths when integrated into rootfs:
- /usr/local/bin/falco
- /usr/local/bin/falcoctl (optional)
- /usr/share/falco/*
- /usr/share/falco/falco.ko
- /etc/falco/falco.yaml
- /etc/falco/falco_rules.yaml
- /etc/falco/falco_rules.local.yaml
- /etc/falco/config.d/falco.container_plugin.board.yaml
- /etc/falco/config.d/falco.json_output.board.yaml
- /etc/systemd/system/falco.service
- /opt/falco-test/falco-start.sh
- /opt/falco-test/load-falco-ko.sh

Post-install on target:
1) systemctl daemon-reload
2) systemctl enable falco
3) systemctl restart falco
4) journalctl -u falco -n 120 --no-pager
EOF

if [[ "${MAKE_TAR}" -eq 1 ]]; then
    TAR_PATH="${OUTPUT_DIR}.tar.gz"
    tar -C "$(dirname "${OUTPUT_DIR}")" -czf "${TAR_PATH}" "$(basename "${OUTPUT_DIR}")"
    echo "[OK] TAR created: ${TAR_PATH}"
fi

echo "[OK] OTA bundle ready: ${OUTPUT_DIR}"
