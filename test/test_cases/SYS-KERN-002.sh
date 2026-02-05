#!/usr/bin/env bash
# SYS-KERN-002: ptrace system call abuse (process injection/debugging)
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 3: Abnormal System Calls & Kernel Behavior

set -e

echo "=========================================="
echo "SYS-KERN-002: ptrace abuse"
echo "=========================================="
echo ""
echo "Expected Baseline: ptrace restricted; only for self/approved debuggers."
echo "Anomaly Condition: PTRACE_ATTACH or POKETEXT on non-self process."
echo "Evidence Fields: pid, target_pid, exe, uid"
echo ""

check_falco() {
    if ! pgrep -x falco > /dev/null 2>&1; then
        echo "Warning: Falco is not running. Start with: sudo falco -c /etc/falco/falco.yaml &"
        if [ -t 0 ]; then
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] || exit 1
        else
            echo "Non-interactive mode: continuing anyway..."
        fi
    fi
}

check_falco

echo ">>> Executing: ptrace attach (strace/gdb on another process)"
echo ""

# strace attaches to a process via ptrace
sleep 3 &
TARGET_PID=$!
sleep 0.5
strace -p $TARGET_PID -e trace=none 2>/dev/null &
STRACE_PID=$!
sleep 1
kill $STRACE_PID 2>/dev/null || true
kill $TARGET_PID 2>/dev/null || true
wait $TARGET_PID 2>/dev/null || true
wait $STRACE_PID 2>/dev/null || true

# Alternative: gdb attach (requires gdb)
if command -v gdb &>/dev/null; then
    echo "Attempting gdb attach to init (PID 1)"
    echo "quit" | sudo gdb -p 1 -batch 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Process_Injection"
echo "    - ptrace or debugger attach"
echo "    tail -f /var/log/falco.log"
echo ""
