#!/usr/bin/env bash
# SYS-KERN-003: Abnormal capset/capget operations
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 3: Abnormal System Calls & Kernel Behavior

set -e

echo "=========================================="
echo "SYS-KERN-003: capset operations"
echo "=========================================="
echo ""
echo "Expected Baseline: capset limited to expected services."
echo "Anomaly Condition: capset assigning high-risk capabilities."
echo "Evidence Fields: pid, exe, new_caps, uid"
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

echo ">>> Executing: Processes that use capset (ping, setcap, etc.)"
echo ""

# ping uses capabilities; setcap modifies capabilities
ping -c 1 127.0.0.1 2>/dev/null || true
getcap /usr/bin/ping 2>/dev/null || getcap /bin/ping 2>/dev/null || true

# setcap on a test file if available
TEST_BIN="/tmp/cap_test_$(date +%s)"
cp -f /bin/true "$TEST_BIN" 2>/dev/null || cp -f /usr/bin/true "$TEST_BIN" 2>/dev/null || true
if [ -f "$TEST_BIN" ] && command -v setcap &>/dev/null; then
    sudo setcap cap_net_raw+ep "$TEST_BIN" 2>/dev/null || true
    sudo setcap -r "$TEST_BIN" 2>/dev/null || true
fi
rm -f "$TEST_BIN" 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Privilege_Escalation_Attempt"
echo "    - capset or capability elevation"
echo "    tail -f /var/log/falco.log"
echo ""
