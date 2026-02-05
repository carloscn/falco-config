#!/usr/bin/env bash
# Test Case 8: System File Modification Detection
# Test Objective: Verify Falco can detect modifications to critical system files

set -e

echo "=========================================="
echo "Test Case 8: System File Modification Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect modifications to critical system files"
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

echo "Executing test operation: Attempting to modify critical system files"
echo "Expected: Falco should detect write operations to critical system files"
echo ""

# Try to modify /etc/passwd (highly monitored file)
echo ">>> Executing: Attempting to append to /etc/passwd"
echo "# test entry falco" | sudo tee -a /etc/passwd > /dev/null 2>&1 || {
    echo "  Note: Operation may fail, but should trigger Falco detection"
}

# Remove test entry if added
sudo sed -i '/test entry falco/d' /etc/passwd 2>&1 || true

# Try to modify /etc/shadow (most sensitive file)
echo ""
echo ">>> Executing: Attempting to modify /etc/shadow"
echo "# test" | sudo tee -a /etc/shadow > /dev/null 2>&1 || {
    echo "  Note: Operation will likely fail, but should trigger Falco detection"
}

# Try to modify /etc/hosts (system configuration file)
echo ""
echo ">>> Executing: Attempting to modify /etc/hosts"
echo "127.0.0.1 test.falco.local" | sudo tee -a /etc/hosts > /dev/null 2>&1 || true

# Clean up if modification succeeded
if grep -q "test.falco.local" /etc/hosts 2>/dev/null; then
    sudo sed -i '/test.falco.local/d' /etc/hosts
fi

# Try to write to /etc directory (should trigger "File below /etc opened for writing" rule)
echo ""
echo ">>> Executing: Creating file in /etc directory"
sudo touch /etc/test_falco_file_$(date +%s) 2>&1 || true
sudo rm -f /etc/test_falco_file_* 2>&1 || true

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for system file modification warnings:"
echo "  - Rule: 'File below /etc opened for writing'"
echo "  - File: /etc/passwd, /etc/shadow, /etc/hosts"
echo "  - Process: process=tee, touch"
echo "  - Write operations to system directories"
echo ""
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
