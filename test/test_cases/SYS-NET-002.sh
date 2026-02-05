#!/usr/bin/env bash
# SYS-NET-002: Unexpected inbound listening on low ports
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 4: Abnormal Network Behavior

set -e

echo "=========================================="
echo "SYS-NET-002: Low port listening"
echo "=========================================="
echo ""
echo "Expected Baseline: No bind to ports <1024 except approved services."
echo "Anomaly Condition: bind to low port by non-baseline process."
echo "Evidence Fields: pid, exe, local_port, uid"
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

echo ">>> Executing: Bind to low port (e.g., 4444 or 80)"
echo "    Requires root for port <1024."
echo ""

# Bind to low ports (backdoor-like) - use Python for reliable timeout
# Port 4444 is often used for backdoors; port 80 requires root
python3 -c "
import socket
import sys
# Port 4444 - no root needed
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', 4444))
    s.listen(1)
    s.settimeout(1)
    s.accept()
except (OSError, socket.timeout):
    pass
finally:
    try: s.close()
    except: pass
" 2>/dev/null || true

# Port 80 - requires root (low port)
if command -v sudo &>/dev/null; then
    sudo python3 -c "
import socket
import sys
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', 80))
    s.listen(1)
    s.settimeout(1)
    s.accept()
except (OSError, socket.timeout, PermissionError):
    pass
finally:
    try: s.close()
    except: pass
" 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Backdoor_Activity"
echo "    - Listen on low port"
echo "    tail -f /var/log/falco.log"
echo ""
