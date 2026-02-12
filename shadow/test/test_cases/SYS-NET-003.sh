#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-NET-003: SOCK_RAW socket creation"
echo "=========================================="
echo ""
echo "Expected Baseline: Raw sockets prohibited in production."
echo "Anomaly Condition: socket() with SOCK_RAW type."
echo "Evidence Fields: pid, exe, socket_family, socket_type, protocol, uid, capabilities"
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

echo ">>> Executing: Create SOCK_RAW socket (requires CAP_NET_RAW)"
echo ""

python3 -c "
import socket
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)
    s.close()
    print('SOCK_RAW created (CAP_NET_RAW present)')
except PermissionError:
    print('SOCK_RAW blocked (no CAP_NET_RAW)')
except Exception as e:
    print('Error:', e)
" 2>/dev/null || true

ping -c 1 127.0.0.1 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Unauthorized_Network_Access"
echo "    - Raw socket creation"
echo "    tail -f /var/log/falco.log"
echo ""
