#!/usr/bin/env bash
# Test Case 9: Encoded Command Execution Detection
# Test Objective: Verify Falco can detect base64/encoded command execution

set -e

echo "=========================================="
echo "Test Case 9: Encoded Command Execution Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect base64/encoded command execution"
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

echo "Executing test operation: Executing base64 encoded commands that access sensitive files"
echo "Expected: Falco may detect both encoding and sensitive file access"
echo ""

# Execute base64 encoded command that reads sensitive file (more likely to trigger)
echo ">>> Executing: echo 'Y2F0IC9ldGMvc2hhZG93' | base64 -d | bash (reads /etc/shadow)"
echo "Y2F0IC9ldGMvc2hhZG93" | base64 -d | bash 2>&1 || true

echo ""
echo ">>> Executing: bash -c \$(echo 'Y2F0IC9ldGMvcGFzc3dk' | base64 -d) (reads /etc/passwd)"
bash -c $(echo 'Y2F0IC9ldGMvcGFzc3dk' | base64 -d) 2>&1 || true

echo ""
echo ">>> Executing: python3 with base64 encoded command"
python3 -c 'import base64; exec(base64.b64decode("cHJpbnQoJ3Rlc3QnKQ=="))' 2>&1 || true

# Also try encoding a command that writes to /etc
echo ""
echo ">>> Executing: Encoded command that attempts to write to /etc"
ENCODED_CMD=$(echo 'echo "test" | sudo tee -a /etc/hosts' | base64)
echo "$ENCODED_CMD" | base64 -d | bash 2>&1 || true

# Clean up if modification succeeded
if grep -q "^test$" /etc/hosts 2>/dev/null; then
    sudo sed -i '/^test$/d' /etc/hosts
fi

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for encoded command execution warnings:"
echo "  - Process: process=base64, bash, python"
echo "  - Command: base64 decoding operations"
echo "  - Suspicious command execution patterns"
echo "  - If command accesses sensitive files, may trigger 'Sensitive file opened' rule"
echo ""
echo "Note: Falco may detect the underlying command (e.g., cat /etc/shadow) rather than encoding"
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
