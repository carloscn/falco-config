#!/usr/bin/env bash
# SYS-PHY-001: Unexpected USB Mass Storage device insertion
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 8: Physical Interface Attacks (USB Insertion)

set -e

echo "=========================================="
echo "SYS-PHY-001: USB Mass Storage insertion"
echo "=========================================="
echo ""
echo "Expected Baseline: USB Mass Storage prohibited or whitelisted."
echo "Anomaly Condition: udev add, bInterfaceClass==08, not in whitelist."
echo "Evidence Fields: action, subsystem, vendor_id, product_id, serial, bInterfaceClass"
echo ""

check_falco() {
    if ! pgrep -x falco > /dev/null 2>&1; then
        echo "Warning: Falco is not running. Start with: sudo falco -c /etc/falco/falco.yaml &"
        if [ -t 0 ]; then
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] || exit 1
        else
            echo "Non-interactive mode: continuing anyway..."
        fi
    fi
}

check_falco

echo ">>> Manual test: Insert USB Mass Storage device"
echo "    Detection via udev monitor (ACTION=add, bInterfaceClass=08)."
echo ""
echo ">>> Simulating: List USB devices (udevadm)"
udevadm info -e 2>/dev/null | grep -E "ID_VENDOR_ID|ID_MODEL_ID|ID_USB_INTERFACES" | head -10 || true

echo ""
echo ">>> Verification: Check IDPS/udev for:"
echo "    - Physical_Device_Insertion"
echo "    - USB Mass Storage (class 08)"
echo "    tail -f udev monitor or IDPS log"
echo ""
