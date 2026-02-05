#!/usr/bin/env bash
# SYS-CONT-004: Capabilities elevation inside container
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 5: Container / Process Escape Related

set -e

echo "=========================================="
echo "SYS-CONT-004: Capabilities elevation in container"
echo "=========================================="
echo ""
echo "Expected Baseline: Container capabilities restricted to baseline set."
echo "Anomaly Condition: capset assigning additional high-risk capabilities."
echo "Evidence Fields: pid, container_id, exe, new_caps, uid"
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

echo ">>> Executing: Container with added capabilities"
echo "    docker run --rm --cap-add=SYS_ADMIN alpine capsh --print"
echo ""

if command -v docker &>/dev/null; then
    docker run --rm --cap-add=SYS_ADMIN alpine capsh --print 2>/dev/null | head -10 || true
else
    echo "Docker not available. Skip container test."
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Privilege_Escalation_Attempt"
echo "    - Capabilities elevation in container"
echo "    tail -f /var/log/falco.log"
echo ""
