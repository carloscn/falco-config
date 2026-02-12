#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-FILE-004: systemd unit modifications"
echo "=========================================="
echo ""
echo "Expected Baseline: /etc/systemd/system, /lib/systemd/system read-only post-boot."
echo "Anomaly Condition: Write to .service, .timer, .conf files."
echo "Evidence Fields: pid, file_path, exe, uid"
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

TEST_UNIT="/etc/systemd/system/test-falco-sys-file-004-$(date +%s).service"

echo ">>> Executing: Attempt write to systemd unit directory"
echo "    Creating test unit: $TEST_UNIT"
echo "[Unit]
Description=Test Falco SYS-FILE-004
[Service]
ExecStart=/bin/true" | sudo tee "$TEST_UNIT" >/dev/null 2>&1 || true

sudo rm -f "$TEST_UNIT" 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Persistence_Attempt"
echo "    - Write to systemd unit files"
echo "    tail -f /var/log/falco.log"
echo ""
