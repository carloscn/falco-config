#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-PROC-002: Exec from writable directories"
echo "=========================================="
echo ""
echo "Expected Baseline: Execution restricted to /bin, /sbin, /usr/bin, etc."
echo "Anomaly Condition: execve from /tmp, /var/tmp, /dev/shm."
echo "Evidence Fields: pid, exe_path, cmdline, cwd, uid"
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

TEST_SCRIPT="/tmp/sys_proc_002_test_$(date +%s).sh"
echo "#!/bin/sh" > "$TEST_SCRIPT"
echo "echo 'Executed from /tmp'" >> "$TEST_SCRIPT"
chmod +x "$TEST_SCRIPT"

echo ">>> Executing: Run binary from /tmp (prohibited writable directory)"
echo "    $TEST_SCRIPT"
"$TEST_SCRIPT"

rm -f "$TEST_SCRIPT"

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Rule: 'Run shell spawned by a non-allowlisted program' or similar"
echo "    - exe_path containing /tmp"
echo "    tail -f /var/log/falco.log"
echo ""
