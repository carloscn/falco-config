#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-PHY-002: USB HID insertion"
echo "=========================================="
echo ""
echo "Expected Baseline: USB HID disabled; only whitelisted diagnostic tools."
echo "Anomaly Condition: udev add, bInterfaceClass==03, not in whitelist."
echo "Evidence Fields: action, vendor_id, product_id, serial, bInterfaceClass, devnode"
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

echo ">>> Manual test: Insert USB HID device (keyboard/mouse)"
echo "    Detection via udev (ACTION=add, bInterfaceClass=03)."
echo ""
echo ">>> Simulating: List HID devices"
ls -la /dev/hidraw* 2>/dev/null || echo "No /dev/hidraw* devices"
udevadm info -e 2>/dev/null | grep -iE "hid|HID|bInterfaceClass" | head -5 || true

echo ""
echo ">>> Verification: Check IDPS/udev for:"
echo "    - Physical_Device_Insertion"
echo "    - USB HID (class 03)"
echo "    tail -f udev monitor or IDPS log"
echo ""
