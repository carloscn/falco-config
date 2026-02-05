#!/usr/bin/env bash
# SYS-PROC-003: Unexpected interactive shell spawn in non-login context
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 1: Abnormal Process Execution & Privilege Escalation

set -e

echo "=========================================="
echo "SYS-PROC-003: Interactive shell spawn"
echo "=========================================="
echo ""
echo "Expected Baseline: Interactive shells only from approved parents (sshd, systemd)."
echo "Anomaly Condition: Shell with -i flag and non-approved parent."
echo "Evidence Fields: pid, ppid, exe, cmdline, parent_exe, uid"
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

echo ">>> Executing: Spawn interactive shell (bash -i) from script"
echo "    Simulates non-login interactive shell."
echo ""

# Spawn interactive shell briefly - use timeout to avoid hanging
if command -v timeout &>/dev/null; then
    timeout 1 bash -i -c "echo interactive" 2>/dev/null || true
else
    bash -i -c "echo interactive; exit" 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Privilege_Escalation_Attempt"
echo "    - bash -i or sh -i with unexpected parent"
echo "    tail -f /var/log/falco.log"
echo ""
