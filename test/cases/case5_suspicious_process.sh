#!/usr/bin/env bash
# Test Case 5: Suspicious Process Execution Detection
# Test Objective: Verify Falco can detect suspicious process execution

set -e

echo "=========================================="
echo "Test Case 5: Suspicious Process Execution Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect suspicious process execution"
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

echo "Executing test operation: Executing script from /tmp directory (common suspicious behavior)"
echo "Expected: Falco may detect suspicious process execution"
echo ""

# Create temporary script in /tmp (common location for suspicious scripts)
TMP_SCRIPT="/tmp/test_falco_script_$(date +%s).sh"
cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
echo "This is a test script executed from /tmp"
whoami
hostname
EOF

chmod +x "$TMP_SCRIPT"

# Execute script
echo ">>> Executing: $TMP_SCRIPT"
bash "$TMP_SCRIPT" 2>&1

# Also try executing with sh
echo ""
echo ">>> Executing: sh $TMP_SCRIPT"
sh "$TMP_SCRIPT" 2>&1

# Try executing a script that reads sensitive file (more likely to trigger)
echo ""
echo ">>> Executing: Script that reads /etc/shadow"
cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
cat /etc/shadow > /dev/null 2>&1
EOF
chmod +x "$TMP_SCRIPT"
bash "$TMP_SCRIPT" 2>&1 || true

# Clean up
rm -f "$TMP_SCRIPT"

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for suspicious process execution related warnings:"
echo "  - Process path: Executed from /tmp"
echo "  - Process name and command"
echo "  - Execution context"
echo "  - If script reads sensitive files, may trigger 'Sensitive file opened' rule"
echo ""
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
