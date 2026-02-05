#!/usr/bin/env bash
# Test Case 10: Network Connection Anomaly Detection
# Test Objective: Verify Falco can detect abnormal network connections

set -e

echo "=========================================="
echo "Test Case 10: Network Connection Anomaly Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect abnormal network connections"
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

echo "Executing test operation: Creating abnormal network connections"
echo "Expected: Falco may detect suspicious network connection patterns"
echo ""

# Connect to unusual ports
echo ">>> Executing: Connecting to unusual port 4444"
timeout 1 bash -c 'exec 3<>/dev/tcp/127.0.0.1/4444' 2>&1 || true

echo ""
echo ">>> Executing: Using curl to connect to suspicious endpoint"
curl -s --max-time 1 http://127.0.0.1:4444/test 2>&1 || true

echo ""
echo ">>> Executing: Using wget to download from suspicious URL"
wget --timeout=1 --tries=1 -O /dev/null http://127.0.0.1:4444/test 2>&1 || true

# Multiple rapid connections
echo ""
echo ">>> Executing: Multiple rapid connections (potential scanning pattern)"
for port in 22 80 443 8080 8443; do
    timeout 0.1 bash -c "exec 3<>/dev/tcp/127.0.0.1/$port" 2>&1 || true
done

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for network connection warnings:"
echo "  - Process: process=curl, wget, bash"
echo "  - Network connections to unusual ports"
echo "  - Multiple rapid connection attempts"
echo ""
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
