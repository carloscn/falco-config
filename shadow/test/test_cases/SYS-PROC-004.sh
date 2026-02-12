#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-PROC-004: Privilege escalation attempts"
echo "=========================================="
echo ""
echo "Expected Baseline: Only pre-approved setuid binaries (su, sudo, ping)."
echo "Anomaly Condition: Non-baseline setuid or capset with high-risk caps."
echo "Evidence Fields: pid, exe, cmdline, capabilities_before, capabilities_after, uid"
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

echo ">>> Executing: sudo and su (privilege escalation)"
echo ""

sudo -n true 2>/dev/null || sudo true 2>/dev/null || true

if command -v su &>/dev/null; then
    echo "Attempting su (may require password)"
    su -c "id" root 2>/dev/null || su -c "id" 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Privilege_Escalation_Attempt"
echo "    - setuid or sudo/su execution"
echo "    tail -f /var/log/falco.log"
echo ""
