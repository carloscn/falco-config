#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-RES-001: CPU/memory abuse"
echo "=========================================="
echo ""
echo "Expected Baseline: Processes within resource limits."
echo "Anomaly Condition: High CPU (>80%) or memory sustained."
echo "Evidence Fields: pid, exe, cpu_usage_pct, mem_usage_mb, duration_sec"
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

echo ">>> Executing: Brief CPU spike (simulates cryptomining pattern)"
echo ""

python3 -c "
import time
end = time.time() + 2
while time.time() < end:
    pass
" 2>/dev/null || true

yes > /dev/null &
YES_PID=$!
sleep 2
kill $YES_PID 2>/dev/null || true
wait $YES_PID 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Resource_Abuse"
echo "    - High CPU/memory process"
echo "    tail -f /var/log/falco.log"
echo ""
