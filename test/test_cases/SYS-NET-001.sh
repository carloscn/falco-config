#!/usr/bin/env bash
# SYS-NET-001: Outbound connections to non-baseline IPs/ports
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 4: Abnormal Network Behavior

set -e

echo "=========================================="
echo "SYS-NET-001: Non-baseline outbound connections"
echo "=========================================="
echo ""
echo "Expected Baseline: Connections only to whitelisted endpoints."
echo "Anomaly Condition: connect/sendto to non-whitelisted destination."
echo "Evidence Fields: pid, exe, remote_ip, remote_port, protocol, domain"
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

echo ">>> Executing: Outbound connection to external IP (e.g., 8.8.8.8:53)"
echo ""

# DNS query to public resolver
nc -zv 8.8.8.8 53 2>/dev/null || true
curl -s --connect-timeout 2 https://example.com >/dev/null 2>&1 || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Command_And_Control"
echo "    - Outbound connection to non-whitelisted IP/port"
echo "    tail -f /var/log/falco.log"
echo ""
