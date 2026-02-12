#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-FILE-001: Writes to /etc auth files"
echo "=========================================="
echo ""
echo "Expected Baseline: /etc/passwd, /etc/shadow, /etc/sudoers writable only by approved tools."
echo "Anomaly Condition: Write/open to these files by unexpected process."
echo "Evidence Fields: pid, exe, file_path, open_flags, uid"
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

TEST_FILE="/etc/test_falco_sys_file_001_$(date +%s)"

echo ">>> Executing: Attempt write to /etc (auth-related path)"
echo "    touch $TEST_FILE"
sudo touch "$TEST_FILE" 2>/dev/null || {
    echo "Note: May need sudo. Trying: echo > $TEST_FILE"
    echo "test" | sudo tee "$TEST_FILE" >/dev/null 2>&1 || true
}

sudo rm -f "$TEST_FILE" 2>/dev/null || true

echo ""
echo ">>> Also testing: read of /etc/shadow (sensitive file)"
cat /etc/shadow 2>/dev/null | head -1 || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - File_Integrity_Violation"
echo "    - File below /etc opened for writing"
echo "    - Sensitive file opened for reading"
echo "    tail -f /var/log/falco.log"
echo ""
