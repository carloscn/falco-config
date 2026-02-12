#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-LOG-001: Log file tampering"
echo "=========================================="
echo ""
echo "Expected Baseline: Log files append-only or protected."
echo "Anomaly Condition: unlink, truncate, or write to /var/log/* by unexpected process."
echo "Evidence Fields: pid, exe, file_path, operation, uid"
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

TEST_LOG="/var/log/test_falco_sys_log_001_$(date +%s).log"

echo ">>> Executing: Write and truncate in /var/log"
echo "    echo test > $TEST_LOG"
echo "test" | sudo tee "$TEST_LOG" >/dev/null 2>&1 || true

echo ">>> Executing: Truncate log file"
sudo truncate -s 0 "$TEST_LOG" 2>/dev/null || true

sudo rm -f "$TEST_LOG" 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Log_Tampering"
echo "    - Write/truncate/unlink in /var/log"
echo "    tail -f /var/log/falco.log"
echo ""
