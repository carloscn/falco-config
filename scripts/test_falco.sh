#!/usr/bin/env bash
# Falco Test Script for Docker Environment
# Tests Falco installation and triggers test events

set -e

echo "=========================================="
echo "Falco Test Script"
echo "=========================================="
echo ""
echo "Issue explanation:"
echo "  Falco 0.42+ has container functionality as built-in bundled plugin"
echo "  If falco.container_plugin.yaml exists in config.d, it causes duplicate loading conflict"
echo "  Solution: Delete container plugin config file in config.d"
echo ""

# Check if in container
if [ ! -f /.dockerenv ] && ! grep -qa docker /proc/1/cgroup 2>/dev/null; then
    echo "Error: This script should run in Docker container"
    echo "Usage: docker exec -it falco-test-ubuntu bash /tmp/test_falco.sh"
    exit 1
fi

# First check and delete container plugin config
CONTAINER_PLUGIN_CONFIG="/etc/falco/config.d/falco.container_plugin.yaml"
if [ -f "$CONTAINER_PLUGIN_CONFIG" ]; then
    echo "Found container plugin config file, deleting (avoid conflict with built-in plugin)..."
    rm -f "$CONTAINER_PLUGIN_CONFIG"
    rm -f "${CONTAINER_PLUGIN_CONFIG}.backup"
    rm -f "${CONTAINER_PLUGIN_CONFIG}.disabled"
    echo "âœ?Deleted container plugin config file"
    echo ""
fi

# Check if Falco is installed
if ! command -v falco &> /dev/null; then
    echo "Error: Falco is not installed"
    echo "Please run: /tmp/install_falco.sh"
    exit 1
fi

echo "Falco version info:"
falco --version

echo ""
echo "=========================================="
echo "Test 1: Run Falco directly (container plugin config deleted)"
echo "=========================================="
echo "Running: falco --dry-run -c /etc/falco/falco.yaml"
echo ""
if falco --dry-run -c /etc/falco/falco.yaml 2>&1 | head -10; then
    echo ""
    echo "âœ“âœ“âœ?Test passed! Falco can run normally after deleting container plugin config!"
    echo ""
    echo "You can now use Falco directly:"
    echo "  falco"
    echo ""
    echo "LD_PRELOAD not needed (if there are still symbol issues, use method 2)"
    TEST1_PASSED=true
else
    echo "âœ?Test failed, may need LD_PRELOAD (continue to test method 2)"
    TEST1_PASSED=false
fi

# Find libresolv.so path
if [ "$TEST1_PASSED" != "true" ]; then
    echo ""
    echo "=========================================="
    echo "Test 2: Use LD_PRELOAD (alternative method)"
    echo "=========================================="
    echo "Finding libresolv.so..."
    LIBRESOLV_PATH=""
    for path in /lib/x86_64-linux-gnu/libresolv.so.2 /lib64/libresolv.so.2 /usr/lib/x86_64-linux-gnu/libresolv.so.2; do
        if [ -f "$path" ]; then
            LIBRESOLV_PATH="$path"
            echo "âœ?Found: $LIBRESOLV_PATH"
            break
        fi
    done
    
    if [ -z "$LIBRESOLV_PATH" ]; then
        echo "Warning: libresolv.so not found, trying to search..."
        find /lib* -name libresolv.so* 2>/dev/null | head -5
        read -p "Please enter full path to libresolv.so: " LIBRESOLV_PATH
        if [ ! -f "$LIBRESOLV_PATH" ]; then
            echo "Error: File does not exist: $LIBRESOLV_PATH"
            exit 1
        fi
    fi
    
    echo "Running: LD_PRELOAD=$LIBRESOLV_PATH falco --dry-run -c /etc/falco/falco.yaml"
    echo ""
    if LD_PRELOAD="$LIBRESOLV_PATH" falco --dry-run -c /etc/falco/falco.yaml 2>&1 | head -10; then
        echo ""
        echo "âœ“âœ“âœ?Test passed! LD_PRELOAD method works!"
        echo ""
        echo "You can now use Falco:"
        echo "  Method 1: Export environment variable"
        echo "    export LD_PRELOAD=$LIBRESOLV_PATH"
        echo "    falco"
        echo ""
        echo "  Method 2: Specify each time"
        echo "    LD_PRELOAD=$LIBRESOLV_PATH falco"
        echo ""
        echo "  Method 3: Use wrapper script (if created)"
        echo "    /usr/local/bin/falco-wrapper.sh"
    else
        echo ""
        echo "âœ?Test still failed, may need other solutions"
        echo ""
        echo "Please check:"
        echo "  1. Is Falco correctly installed"
        echo "  2. Is configuration correct"
        echo "  3. Does container have sufficient permissions"
    fi
else
    echo ""
    echo "=========================================="
    echo "Test 2: Skipped (Test 1 passed, LD_PRELOAD not needed)"
    echo "=========================================="
fi

echo ""
echo "=========================================="
echo "Test 3: View Falco rules"
echo "=========================================="
echo "Running: falco -L | head -20"
echo ""
falco -L 2>/dev/null | head -20 || echo "Unable to list rules"

echo ""
echo "=========================================="
echo "Test 4: Trigger test event and check logs"
echo "=========================================="
LOG_FILE="/var/log/falco.log"
BEFORE_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
echo "Current log lines: $BEFORE_LINES"
echo ""
echo "Triggering test event: reading /etc/shadow..."
cat /etc/shadow > /dev/null 2>&1 || true

# Wait for Falco to process event
sleep 2

# Check new logs
AFTER_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
NEW_LINES=$((AFTER_LINES - BEFORE_LINES))

echo ""
if [ "$NEW_LINES" -gt 0 ]; then
    echo "âœ“âœ“âœ?Detected $NEW_LINES new log lines!"
    echo ""
    echo "Latest log content:"
    tail -n "$NEW_LINES" "$LOG_FILE"
else
    echo "âš?No new logs detected"
    echo ""
    echo "Possible reasons:"
    echo "  1. Falco rules not triggered (may need to adjust rules)"
    echo "  2. Falco output configuration issue"
    echo "  3. Events filtered"
    echo ""
    echo "Check Falco output configuration:"
    echo "  grep -A 3 'stdout_output:' /etc/falco/falco.yaml"
    echo "  grep -A 5 'file_output:' /etc/falco/falco.yaml"
fi

echo ""
echo "=========================================="
echo "Test completed"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Root cause: Falco 0.42+ has built-in container functionality, config.d config causes conflict"
echo "  - Solution: Delete /etc/falco/config.d/falco.container_plugin.yaml"
echo "  - If Test 1 passed, use directly: falco"
echo "  - If there are still symbol issues, use LD_PRELOAD: LD_PRELOAD=$LIBRESOLV_PATH falco"
echo ""
