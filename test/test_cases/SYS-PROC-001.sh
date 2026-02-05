#!/usr/bin/env bash
# SYS-PROC-001: Process executed with unexpected user/group identity
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 1: Abnormal Process Execution & Privilege Escalation

set -e

echo "=========================================="
echo "SYS-PROC-001: Unexpected uid/gid identity"
echo "=========================================="
echo ""
echo "Expected Baseline: Processes execute under predefined uid/gid mappings."
echo "Anomaly Condition: Process launch with uid/gid not matching baseline."
echo "Evidence Fields: pid, ppid, uid, gid, exe_path, cmdline"
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

echo ">>> Executing: Run process as different user (e.g., runuser or su)"
echo "    Simulates process with non-baseline uid/gid."
echo ""

# Try runuser if available (common on embedded)
if command -v runuser &>/dev/null; then
    echo "Using runuser -u nobody -- id"
    runuser -u nobody -- id 2>/dev/null || true
fi

# Alternative: use sudo -u
if command -v sudo &>/dev/null; then
    echo "Using sudo -u nobody id"
    sudo -u nobody id 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for rule matching:"
echo "    - Abnormal_Process_Execution"
echo "    - uid/gid not in baseline"
echo "    tail -f /var/log/falco.log"
echo ""
