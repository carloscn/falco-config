#!/usr/bin/env bash
# Test Case 11: Process Injection Detection
# Test Objective: Verify Falco can detect process injection attempts

set -e

echo "=========================================="
echo "Test Case 11: Process Injection Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect process injection attempts"
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

echo "Executing test operation: Attempting process injection techniques"
echo "Expected: Falco may detect suspicious process manipulation"
echo ""

# Try ptrace operations (process debugging/injection)
echo ">>> Executing: Attempting ptrace operations"
if command -v strace &> /dev/null; then
    echo "  Using strace to trace process (may trigger detection)"
    timeout 1 strace -e trace=open,openat,read cat /etc/passwd > /dev/null 2>&1 || true
else
    echo "  strace not available, installing..."
    sudo apt-get update && sudo apt-get install -y strace 2>/dev/null || true
    timeout 1 strace -e trace=open,openat,read cat /etc/passwd > /dev/null 2>&1 || true
fi

# Try to attach to process using gdb
echo ""
echo ">>> Executing: Attempting gdb process attachment"
if command -v gdb &> /dev/null; then
    timeout 1 gdb -batch -ex "attach $$" -ex "detach" 2>&1 || true
else
    echo "  gdb not available, skipping"
fi

# Try LD_PRELOAD (library injection)
echo ""
echo ">>> Executing: Using LD_PRELOAD (library injection)"
TEST_LIB="/tmp/test_falco_lib_$(date +%s).so"
cat > /tmp/test_lib.c << 'EOF'
#include <stdio.h>
#include <dlfcn.h>
void __attribute__((constructor)) init() {
    printf("Library loaded\n");
}
EOF

if command -v gcc &> /dev/null; then
    gcc -shared -fPIC -o "$TEST_LIB" /tmp/test_lib.c 2>/dev/null && {
        LD_PRELOAD="$TEST_LIB" whoami 2>&1 || true
        rm -f "$TEST_LIB"
    } || echo "  Compilation failed, but command should be detected"
fi
rm -f /tmp/test_lib.c 2>/dev/null || true

# Try reading process memory via /proc
echo ""
echo ">>> Executing: Reading process memory via /proc (may trigger detection)"
cat /proc/self/maps 2>&1 | head -5 || true

# Try to modify process memory (if possible)
echo ""
echo ">>> Executing: Attempting to write to /proc/self/mem (process memory modification)"
echo "test" | sudo tee /proc/self/mem > /dev/null 2>&1 || {
    echo "  Note: Operation will fail, but attempt should be detected"
}

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for process injection warnings:"
echo "  - Process: process=strace, gdb, process manipulation"
echo "  - Library loading: LD_PRELOAD usage"
echo "  - Process memory access"
echo "  - Ptrace operations"
echo ""
echo "Note: Some process injection techniques may require custom rules"
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
