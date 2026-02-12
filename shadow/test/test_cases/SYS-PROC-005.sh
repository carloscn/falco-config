#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-PROC-005: Unknown/non-baseline binary"
echo "=========================================="
echo ""
echo "Expected Baseline: Only binaries in firmware whitelist permitted."
echo "Anomaly Condition: execve to path not in baseline whitelist."
echo "Evidence Fields: pid, exe_path, cmdline, hash_status, signature_status"
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

UNKNOWN_BIN="/tmp/unknown_bin_$(date +%s)"
cp -f /bin/true "$UNKNOWN_BIN" 2>/dev/null || cp -f /usr/bin/true "$UNKNOWN_BIN" 2>/dev/null || true

if [ -f "$UNKNOWN_BIN" ]; then
    echo ">>> Executing: Run binary from non-baseline path"
    echo "    $UNKNOWN_BIN"
    "$UNKNOWN_BIN"
    rm -f "$UNKNOWN_BIN"
else
    echo ">>> Executing: Run script from /tmp (non-whitelisted path)"
    SCRIPT="/tmp/non_baseline_$(date +%s).sh"
    echo "#!/bin/sh" > "$SCRIPT"
    echo "echo test" >> "$SCRIPT"
    chmod +x "$SCRIPT"
    "$SCRIPT"
    rm -f "$SCRIPT"
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Abnormal_Process_Execution"
echo "    - exe_path not in baseline"
echo "    tail -f /var/log/falco.log"
echo ""
