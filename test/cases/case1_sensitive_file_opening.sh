#!/usr/bin/env bash
# Test Case 1: Sensitive File Read Detection
# Test Objective: Verify Falco can detect sensitive files being read

set -e

echo "=========================================="
echo "Test Case 1: Sensitive File Read Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect /etc/shadow file being read"
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

echo "Executing test operation: Reading /etc/shadow file using multiple methods"
echo "Expected: Falco should detect this operation and generate warning log"
echo ""

# Get current log line count
LOG_FILE="/var/log/falco.log"
BEFORE_LINES=$(sudo wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
echo "Current log lines: $BEFORE_LINES"
echo ""

# Try multiple methods to read the file (increase detection probability)
echo ">>> Method 1: Using cat to read /etc/shadow"
cat /etc/shadow > /dev/null 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 2: Using head to read /etc/shadow"
head -1 /etc/shadow > /dev/null 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 3: Using tail to read /etc/shadow"
tail -1 /etc/shadow > /dev/null 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 4: Using grep to search /etc/shadow"
grep -q "." /etc/shadow 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 5: Using awk to read /etc/shadow"
awk '{print $1}' /etc/shadow > /dev/null 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 6: Using sed to read /etc/shadow"
sed -n '1p' /etc/shadow > /dev/null 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 7: Using python to read /etc/shadow"
python3 -c "open('/etc/shadow').read()" 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 8: Using bash file descriptor to read /etc/shadow"
exec 3< /etc/shadow
read -u 3 line 2>/dev/null || true
exec 3<&-
sleep 0.5

# Also try reading other sensitive files
echo ""
echo ">>> Method 9: Reading /etc/passwd (another sensitive file)"
cat /etc/passwd > /dev/null 2>&1 || true
sleep 0.5

echo ""
echo ">>> Method 10: Reading /etc/gshadow (sensitive file)"
cat /etc/gshadow > /dev/null 2>&1 || true
sleep 0.5

# Check for new logs
AFTER_LINES=$(sudo wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
NEW_LINES=$((AFTER_LINES - BEFORE_LINES))

echo ""
echo ">>> Test operation completed"
echo ""
if [ "$NEW_LINES" -gt 0 ]; then
    echo "✓✓✓ Detected $NEW_LINES new log lines!"
    echo ""
    echo "Latest log content:"
    sudo tail -n "$NEW_LINES" "$LOG_FILE"
    echo ""
    
    # Check if it's the expected rule
    if sudo tail -n "$NEW_LINES" "$LOG_FILE" | grep -qi "sensitive file\|read sensitive"; then
        echo "✓✓✓ SUCCESS! Detected 'Read sensitive file' rule as expected!"
    elif sudo tail -n "$NEW_LINES" "$LOG_FILE" | grep -qi "Executing binary not part of base image"; then
        echo "⚠ WARNING: Detected 'Executing binary not part of base image' rule instead"
        echo "This means Falco detected command execution, but not the file read"
        echo "The 'Read sensitive file' rule may not be triggering"
        echo "Try running: bash cases/case1_debug.sh for detailed diagnosis"
    else
        echo "⚠ Detected logs but may not be the expected 'Read sensitive file' rule"
        echo "Check the log above to see which rule was triggered"
    fi
else
    echo "⚠ No new logs detected"
    echo ""
    echo "Possible reasons:"
    echo "  1. Falco rules may not be enabled - Check: sudo falco -L | grep -i 'Read sensitive file'"
    echo "  2. Process may be considered 'trusted' - Falco has exceptions for trusted programs"
    echo "  3. Rule conditions may not be met - Check rule details"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check if rules are enabled:"
    echo "     sudo falco -L | grep -A 5 'Read sensitive file'"
    echo ""
    echo "  2. Run debug script:"
    echo "     bash cases/case1_debug.sh"
    echo ""
    echo "  3. Check Falco configuration:"
    echo "     sudo cat /etc/falco/falco.yaml | grep -A 10 'rules_file'"
    echo ""
    echo "  4. Try running Falco with verbose output:"
    echo "     sudo pkill falco"
    echo "     sudo falco -v -c /etc/falco/falco.yaml 2>&1 | tee /tmp/falco_verbose.log"
fi
echo ""
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
