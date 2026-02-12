#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-CONT-001: Container host path access"
echo "=========================================="
echo ""
echo "Expected Baseline: Containers isolated; no access to host /root, /proc, /sys."
echo "Anomaly Condition: Open/read/write to host-sensitive paths from container."
echo "Evidence Fields: pid, container_id, exe, accessed_path, uid"
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

echo ">>> Executing: From inside container, access host paths"
echo "    Run: docker run --rm alpine cat /proc/1/cmdline"
echo ""

if command -v docker &>/dev/null; then
    docker run --rm alpine cat /proc/1/cmdline 2>/dev/null || true
    docker run --rm alpine ls -la /host/proc 2>/dev/null || true
else
    echo "Docker not available. Simulating: read /proc/1/cmdline"
    cat /proc/1/cmdline 2>/dev/null | tr '\0' ' ' || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Container_Escape"
echo "    - Container access to host paths"
echo "    tail -f /var/log/falco.log"
echo ""
