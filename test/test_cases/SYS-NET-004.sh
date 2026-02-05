#!/usr/bin/env bash
# SYS-NET-004: Creation of AF_CAN (CAN bus) sockets
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 4: Abnormal Network Behavior

set -e

echo "=========================================="
echo "SYS-NET-004: AF_CAN socket creation"
echo "=========================================="
echo ""
echo "Expected Baseline: AF_CAN restricted to dedicated CAN services."
echo "Anomaly Condition: socket() with AF_CAN family."
echo "Evidence Fields: pid, exe, socket_family, socket_type, protocol, uid, interface"
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

# AF_CAN = 29 (from linux/socket.h)
echo ">>> Executing: Create AF_CAN socket"
echo ""

python3 -c "
import socket
# AF_CAN = 29, SOCK_RAW = 3, CAN_RAW = 1
try:
    s = socket.socket(29, 3, 1)  # AF_CAN, SOCK_RAW, CAN_RAW
    s.close()
    print('AF_CAN socket created')
except (OSError, socket.error) as e:
    print('AF_CAN socket failed (expected on non-CAN systems):', e)
" 2>/dev/null || true

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Unauthorized_Network_Access"
echo "    - AF_CAN socket creation"
echo "    tail -f /var/log/falco.log"
echo ""
