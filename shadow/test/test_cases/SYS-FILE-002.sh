#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-FILE-002: Modifications to /bin, /usr/bin"
echo "=========================================="
echo ""
echo "Expected Baseline: /bin, /sbin, /usr/bin, /usr/sbin read-only."
echo "Anomaly Condition: Write attempt to these directories."
echo "Evidence Fields: pid, exe, file_path, uid"
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

TEST_FILE="/usr/bin/test_falco_sys_file_002_$(date +%s)"

echo ">>> Executing: Attempt write to /usr/bin"
echo "    touch $TEST_FILE"
sudo touch "$TEST_FILE" 2>/dev/null || echo "test" | sudo tee "$TEST_FILE" >/dev/null 2>&1 || true

sudo rm -f "$TEST_FILE" 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - File_Integrity_Violation"
echo "    - Write to system binary directory"
echo "    tail -f /var/log/falco.log"
echo ""
