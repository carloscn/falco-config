#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-RES-003: Fork bomb / mass spawning"
echo "=========================================="
echo ""
echo "Expected Baseline: Normal process trees, limited depth."
echo "Anomaly Condition: Deep or rapid fork chain from non-baseline parent."
echo "Evidence Fields: pid, ppid, exe, child_count, spawn_rate"
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

echo ">>> Executing: Rapid fork (limited - 20 children in 1 sec)"
echo "    Full fork bomb would be: :(){ :|:& };:"
echo ""

for i in $(seq 1 20); do
    (sleep 2) &
done
wait 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Resource_Abuse"
echo "    - Abnormal fork rate"
echo "    tail -f /var/log/falco.log"
echo ""
