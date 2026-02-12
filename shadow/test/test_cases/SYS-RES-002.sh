#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-RES-002: Hidden process (deleted exe)"
echo "=========================================="
echo ""
echo "Expected Baseline: No processes from deleted/unlinked files."
echo "Anomaly Condition: /proc/<pid>/exe links to (deleted) file."
echo "Evidence Fields: pid, exe_path (deleted), cmdline, uid"
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

HIDDEN_BIN="/tmp/hidden_$(date +%s)"
cp -f /bin/sleep "$HIDDEN_BIN" 2>/dev/null || cp -f /usr/bin/sleep "$HIDDEN_BIN" 2>/dev/null || true

if [ -f "$HIDDEN_BIN" ]; then
    echo ">>> Executing: Run binary then unlink while running"
    "$HIDDEN_BIN" 60 &
    PID=$!
    sleep 1
    rm -f "$HIDDEN_BIN"
    echo "    Process $PID now has deleted exe (check /proc/$PID/exe)"
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
else
    echo ">>> Executing: Run script, delete it, keep running"
    SCRIPT="/tmp/hidden_script_$(date +%s).sh"
    echo "#!/bin/sh" > "$SCRIPT"
    echo "sleep 5" >> "$SCRIPT"
    chmod +x "$SCRIPT"
    "$SCRIPT" &
    PID=$!
    sleep 1
    rm -f "$SCRIPT"
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Hidden_Process"
echo "    - Process from deleted binary"
echo "    tail -f /var/log/falco.log"
echo ""
