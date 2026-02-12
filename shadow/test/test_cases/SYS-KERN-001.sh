#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-KERN-001: Kernel module loading"
echo "=========================================="
echo ""
echo "Expected Baseline: Module loading disabled; no insmod/modprobe."
echo "Anomaly Condition: init_module or finit_module syscall."
echo "Evidence Fields: pid, exe, module_name, uid"
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

echo ">>> Executing: Attempt to load kernel module (modprobe/insmod)"
echo "    This may fail with permission error - detection happens on syscall."
echo ""

modprobe -l 2>/dev/null || true
insmod --help 2>/dev/null || true
sudo modprobe -n dummy 2>/dev/null || sudo insmod /lib/modules/$(uname -r)/kernel/drivers/net/dummy.ko 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Kernel_Integrity_Violation"
echo "    - Init module loaded"
echo "    tail -f /var/log/falco.log"
echo ""
