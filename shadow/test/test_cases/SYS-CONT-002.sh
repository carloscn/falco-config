#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-CONT-002: Privileged container"
echo "=========================================="
echo ""
echo "Expected Baseline: Containers start unprivileged."
echo "Anomaly Condition: Container with CAP_SYS_ADMIN or --privileged."
echo "Evidence Fields: pid, container_id, exe, capabilities, uid"
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

echo ">>> Executing: Start privileged container"
echo "    docker run --rm --privileged alpine id"
echo ""

if command -v docker &>/dev/null; then
    docker run --rm --privileged alpine id 2>/dev/null || true
else
    echo "Docker not available. Skip container test."
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Container_Escape"
echo "    - Privileged container started"
echo "    tail -f /var/log/falco.log"
echo ""
