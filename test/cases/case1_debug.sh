#!/usr/bin/env bash
# Debug script for Case 1 - Check why sensitive file reads are not detected

set -e

echo "=========================================="
echo "Case 1 Debug Script"
echo "=========================================="
echo ""

# Check Falco is running
if ! pgrep -x falco > /dev/null; then
    echo "ERROR: Falco is not running!"
    echo "Start Falco: sudo falco -c /etc/falco/falco.yaml &"
    exit 1
fi

echo "✓ Falco is running (PID: $(pgrep -x falco))"
echo ""

# Check current user
echo "Current user: $(whoami)"
echo "User ID: $(id -u)"
echo "Groups: $(groups)"
echo ""

# Check sensitive file read rules (without triggering them)
echo "Checking Falco rules for sensitive file reads..."
echo "=========================================="
echo "Note: Running 'falco -L' may trigger 'Executing binary not part of base image' rule"
echo "This is expected - we're checking rules, not testing file reads"
echo ""

# Save current log count before checking rules
LOG_FILE="/var/log/falco.log"
BEFORE_RULE_CHECK=$(sudo wc -l < "$LOG_FILE" 2>/dev/null || echo "0")

# Check rules (this will trigger a log entry, but that's OK)
SENSITIVE_RULES=$(sudo falco -L 2>/dev/null | grep -B 2 -A 10 "Read sensitive file")
if [ -n "$SENSITIVE_RULES" ]; then
    echo "$SENSITIVE_RULES"
else
    echo "WARNING: No 'Read sensitive file' rules found!"
fi
echo ""

# Wait a moment for any rule-check logs to be written
sleep 1

# Check if rules are enabled
echo "Checking if rules are enabled..."
echo "=========================================="
ENABLED_RULES=$(sudo falco -L 2>/dev/null | grep -E "rule:|enabled:" | grep -A 1 "Read sensitive file")
if [ -n "$ENABLED_RULES" ]; then
    echo "$ENABLED_RULES"
else
    echo "WARNING: Cannot determine rule status"
fi
echo ""

# Check Falco configuration
echo "Checking Falco configuration..."
echo "=========================================="
echo "Rules files:"
sudo grep -E "rules_file|rules_dir" /etc/falco/falco.yaml 2>/dev/null | head -5 || echo "Cannot read config"
echo ""

# Now test reading /etc/shadow (this is what we actually want to test)
echo "=========================================="
echo "Testing: Attempting to read /etc/shadow"
echo "=========================================="
echo "This should trigger 'Read sensitive file untrusted' rule"
echo ""

# Get log count BEFORE reading the file
BEFORE_READ=$(sudo wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
echo "Log lines before reading /etc/shadow: $BEFORE_READ"

# Try reading with cat (most common method)
echo ""
echo ">>> Executing: cat /etc/shadow"
cat /etc/shadow > /dev/null 2>&1 || true

# Wait for Falco to process the event
echo "Waiting for Falco to process event..."
sleep 3

# Check log count AFTER reading
AFTER_READ=$(sudo wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
NEW_LINES=$((AFTER_READ - BEFORE_READ))

echo "Log lines after reading /etc/shadow: $AFTER_READ"
echo "New log lines: $NEW_LINES"
echo ""

if [ "$NEW_LINES" -gt 0 ]; then
    echo "✓✓✓ SUCCESS! Detected $NEW_LINES new log line(s)!"
    echo ""
    echo "Latest log content:"
    echo "=========================================="
    sudo tail -n "$NEW_LINES" "$LOG_FILE"
    echo ""
    
    # Check if it's the expected rule
    if sudo tail -n "$NEW_LINES" "$LOG_FILE" | grep -qi "sensitive file"; then
        echo "✓✓✓ PERFECT! This is the expected 'Read sensitive file' rule!"
    else
        echo "⚠ WARNING: Log detected but may not be the expected rule"
        echo "Expected: 'Read sensitive file untrusted' or 'Read sensitive file trusted after startup'"
        echo "Check the log above to see which rule was triggered"
    fi
else
    echo "✗ FAILED: No new logs detected after reading /etc/shadow"
    echo ""
    echo "Diagnosis:"
    echo "=========================================="
    
    # Check rule conditions
    echo "1. Checking rule conditions..."
    RULE_INFO=$(sudo falco -L 2>/dev/null | grep -A 30 "Read sensitive file untrusted")
    if [ -n "$RULE_INFO" ]; then
        echo "Rule details:"
        echo "$RULE_INFO" | head -20
    else
        echo "Cannot find rule details"
    fi
    echo ""
    
    # Check trusted programs
    echo "2. Checking for trusted program exceptions..."
    TRUSTED=$(sudo falco -L 2>/dev/null | grep -A 50 "Read sensitive file untrusted" | grep -i "proc.name\|trusted\|exception" | head -10)
    if [ -n "$TRUSTED" ]; then
        echo "Trusted program info:"
        echo "$TRUSTED"
    else
        echo "Cannot find trusted program info"
    fi
    echo ""
    
    # Check process name
    echo "3. Current process info:"
    echo "   Process: $(basename $0)"
    echo "   Full path: $0"
    echo "   Parent: $(ps -o comm= -p $PPID 2>/dev/null || echo 'unknown')"
    echo "   Command: cat /etc/shadow"
    echo ""
    
    echo "Possible solutions:"
    echo "  1. Check if 'cat' is in trusted programs list"
    echo "  2. Try using a different process (e.g., /usr/bin/cat directly)"
    echo "  3. Check rule priority - may be set to 'debug' or 'informational'"
    echo "  4. Verify Falco is capturing syscalls correctly"
    echo "  5. Check if rule is actually enabled"
    echo ""
    echo "Try manually:"
    echo "  sudo falco -v -c /etc/falco/falco.yaml 2>&1 | grep -i shadow"
fi

echo ""
echo "=========================================="
echo "Note about 'Executing binary not part of base image' log:"
echo "This log appears when running 'falco -L' to check rules."
echo "It's expected and not related to testing file reads."
echo "The important test is reading /etc/shadow above."
echo "=========================================="
echo ""
