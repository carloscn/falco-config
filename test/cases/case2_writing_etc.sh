#!/usr/bin/env bash
# Test Case 2: System Directory Write Detection
# Test Objective: Verify Falco can detect write operations to /etc directory

set -e

echo "=========================================="
echo "Test Case 2: System Directory Write Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect write operations to /etc directory"
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

TEST_FILE="/etc/testfile_falco_$(date +%s)"

echo "Executing test operation: Creating test file in /etc directory"
echo "Expected: Falco should detect this operation and generate warning log"
echo ""

# Execute write operation
echo ">>> Executing: sudo touch $TEST_FILE"
sudo touch "$TEST_FILE" 2>&1 || {
    echo "Note: May need root/sudo permissions to write to /etc directory"
    echo "Trying with sudo..."
    sudo touch "$TEST_FILE" 2>&1 || true
}

# Clean up test file
if [ -f "$TEST_FILE" ]; then
    echo ">>> Cleaning up test file: sudo rm $TEST_FILE"
    sudo rm -f "$TEST_FILE" 2>&1 || true
fi

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output, you should see warnings similar to:"
echo "  - Rule: 'File below /etc opened for writing'"
echo "  - File: fd.name=$TEST_FILE"
echo "  - Process: process=touch"
echo ""
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
