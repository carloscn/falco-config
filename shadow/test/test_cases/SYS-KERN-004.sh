#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-KERN-004: mount/umount operations"
echo "=========================================="
echo ""
echo "Expected Baseline: Root filesystem read-only; no remount rw."
echo "Anomaly Condition: mount with MS_REMOUNT on /, /boot, /recovery."
echo "Evidence Fields: pid, exe, mount_path, mount_flags, source_device, uid"
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

echo ">>> Executing: mount/umount operations"
echo ""

mount | head -5

echo "Attempting remount (may fail): mount -o remount,rw /"
sudo mount -o remount,rw / 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Kernel_Integrity_Violation"
echo "    - Unexpected mount or remount"
echo "    tail -f /var/log/falco.log"
echo ""
