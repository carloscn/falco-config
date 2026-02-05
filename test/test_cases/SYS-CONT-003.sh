#!/usr/bin/env bash
# SYS-CONT-003: Mounting host sensitive directories inside container
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 5: Container / Process Escape Related

set -e

echo "=========================================="
echo "SYS-CONT-003: Host dir mount in container"
echo "=========================================="
echo ""
echo "Expected Baseline: No bind of host /proc, /sys, docker.sock, /etc."
echo "Anomaly Condition: mount of host-sensitive paths in container."
echo "Evidence Fields: pid, container_id, mount_source, mount_target, uid"
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

echo ">>> Executing: Container with host /etc mounted"
echo "    docker run --rm -v /etc:/host-etc alpine ls /host-etc"
echo ""

if command -v docker &>/dev/null; then
    docker run --rm -v /etc:/host-etc alpine ls /host-etc 2>/dev/null | head -5 || true
else
    echo "Docker not available. Skip container test."
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Container_Escape"
echo "    - Sensitive directory mount"
echo "    tail -f /var/log/falco.log"
echo ""
