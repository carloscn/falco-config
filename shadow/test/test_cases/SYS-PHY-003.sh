#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-PHY-003: Generic USB insertion"
echo "=========================================="
echo ""
echo "Expected Baseline: Only whitelisted vendor:product allowed."
echo "Anomaly Condition: udev add, DEVTYPE=usb_device, not in whitelist."
echo "Evidence Fields: action, vendor_id, product_id, serial, bDeviceClass, product"
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

echo ">>> Manual test: Insert any non-whitelisted USB device"
echo "    Detection via udev (ACTION=add, SUBSYSTEM=usb)."
echo ""
echo ">>> Simulating: Enumerate USB devices"
lsusb 2>/dev/null || true
udevadm info -e -n /dev/bus/usb 2>/dev/null | head -20 || true

echo ""
echo ">>> Verification: Check IDPS/udev for:"
echo "    - Physical_Device_Insertion"
echo "    - Non-whitelisted USB device"
echo "    tail -f udev monitor or IDPS log"
echo ""
