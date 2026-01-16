#!/usr/bin/env bash
# Test Case 12: Mass File Access Detection
# Test Objective: Verify Falco can detect mass file access patterns

set -e

echo "=========================================="
echo "Test Case 12: Mass File Access Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect mass file access patterns"
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

echo "Executing test operation: Rapidly accessing multiple sensitive files"
echo "Expected: Falco should detect mass access to sensitive files"
echo ""

# Access multiple sensitive files rapidly (more likely to trigger Falco)
echo ">>> Executing: Rapidly reading multiple sensitive files"
for file in /etc/shadow /etc/passwd /etc/group /etc/gshadow /etc/sudoers; do
    if [ -r "$file" ]; then
        cat "$file" > /dev/null 2>&1 || true
    fi
done

# Create test directory with multiple files
TEST_DIR="/tmp/falco_mass_access_$(date +%s)"
mkdir -p "$TEST_DIR"

echo ""
echo ">>> Creating test files and accessing them rapidly..."
for i in {1..100}; do
    echo "test content $i" > "$TEST_DIR/file_$i.txt"
    # Access each file immediately after creation
    cat "$TEST_DIR/file_$i.txt" > /dev/null 2>&1
done

echo ""
echo ">>> Executing: Using find to access many files rapidly"
find "$TEST_DIR" -type f -exec cat {} \; > /dev/null 2>&1 || true

echo ""
echo ">>> Executing: Using grep across multiple files"
grep -r "test" "$TEST_DIR" > /dev/null 2>&1 || true

# Also try accessing /etc files rapidly
echo ""
echo ">>> Executing: Rapidly accessing /etc directory files"
for file in /etc/hosts /etc/resolv.conf /etc/hostname /etc/fstab; do
    cat "$file" > /dev/null 2>&1 || true
done

# Clean up
rm -rf "$TEST_DIR"

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for mass file access warnings:"
echo "  - Process: process=cat, find, grep"
echo "  - Multiple file access in short time"
echo "  - File enumeration patterns"
echo "  - If accessing sensitive files, may trigger 'Sensitive file opened' rule multiple times"
echo ""
echo "Note: Falco may detect individual file accesses rather than mass access pattern"
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
