#!/usr/bin/env bash
# Test Case 6: File Permission Modification Detection
# Test Objective: Verify Falco can detect suspicious file permission modifications

set -e

echo "=========================================="
echo "Test Case 6: File Permission Modification Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect suspicious file permission modifications"
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

# Try to modify permissions of sensitive files (more likely to trigger Falco)
echo "Executing test operation: Modifying permissions of sensitive files"
echo "Expected: Falco should detect permission modifications to sensitive files"
echo ""

# Try to modify /etc/shadow permissions (highly suspicious)
echo ">>> Executing: sudo chmod 644 /etc/shadow (simulating permission change)"
sudo chmod 644 /etc/shadow 2>&1 || {
    echo "  Note: Operation may fail, but should trigger Falco detection"
}

# Restore original permissions if changed
sudo chmod 640 /etc/shadow 2>&1 || true

# Try to modify /etc/passwd permissions
echo ""
echo ">>> Executing: sudo chmod 666 /etc/passwd (world-writable, highly suspicious)"
sudo chmod 666 /etc/passwd 2>&1 || true

# Restore
sudo chmod 644 /etc/passwd 2>&1 || true

# Create and modify test file in /tmp
TEST_FILE="/tmp/test_falco_perms_$(date +%s).txt"
echo "test content" > "$TEST_FILE"

echo ""
echo ">>> Executing: chmod 777 $TEST_FILE (world-writable)"
chmod 777 "$TEST_FILE" 2>&1

# Clean up
rm -f "$TEST_FILE"

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for file permission modification warnings:"
echo "  - Process: process=chmod"
echo "  - File: /etc/shadow, /etc/passwd (sensitive files)"
echo "  - Permission changes"
echo ""
echo "Note: Falco may only detect modifications to sensitive system files"
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
