#!/usr/bin/env bash
# Test Case 3: Network Port Scan Detection
# Test Objective: Verify Falco can detect network port scanning behavior

set -e

echo "=========================================="
echo "Test Case 3: Network Port Scan Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect network port scanning behavior"
echo ""

# Check if Falco is running
if ! pgrep -x falco > /dev/null; then
    echo "Warning: Falco process is not running, please start Falco first"
    echo "Start command: falco -c /etc/falco/falco.yaml & (in another terminal)"
    echo ""
    read -p "Continue test? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if nmap is installed
if ! command -v nmap &> /dev/null; then
    echo "nmap is not installed, installing..."
    sudo apt-get update && sudo apt-get install -y nmap || {
        echo "Error: Unable to install nmap"
        exit 1
    }
fi

echo "Executing test operation: Performing port scan"
echo "Expected: Falco may detect network scanning behavior (depends on rule configuration)"
echo ""

# Execute port scan (scan localhost to avoid affecting external)
echo ">>> Executing: nmap -p 22,80,443 127.0.0.1"
nmap -p 22,80,443 127.0.0.1 2>&1 || true

echo ""
echo ">>> Test operation completed"
echo ""
echo "Note: Network behavior detection may require custom rules"
echo "Default Falco rules may not include all network scan pattern detection"
echo ""
echo "Please check Falco log output for network-related warnings:"
echo "  - Process: process=nmap"
echo "  - Network connection information"
echo ""
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
