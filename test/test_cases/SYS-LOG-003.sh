#!/usr/bin/env bash
# SYS-LOG-003: Termination of log collection processes
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 7: Log & Audit Integrity

set -e

echo "=========================================="
echo "SYS-LOG-003: Log process termination"
echo "=========================================="
echo ""
echo "Expected Baseline: syslogd, auditd, journald not terminated."
echo "Anomaly Condition: kill/SIGTERM to log daemon by non-system user."
echo "Evidence Fields: pid, target_pid, exe (killer), signal, uid"
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

echo ">>> Executing: Send signal to log-related process (simulated)"
echo "    WARNING: Do NOT actually kill syslog/auditd in production."
echo ""

# Find rsyslog or syslog-ng or similar
LOG_PID=$(pgrep -x rsyslogd 2>/dev/null | head -1)
if [ -z "$LOG_PID" ]; then
    LOG_PID=$(pgrep -x syslogd 2>/dev/null | head -1)
fi
if [ -z "$LOG_PID" ]; then
    LOG_PID=$(pgrep -x syslog-ng 2>/dev/null | head -1)
fi

if [ -n "$LOG_PID" ]; then
    echo "Found log process PID $LOG_PID. Sending SIGUSR1 (harmless) instead of SIGTERM."
    sudo kill -USR1 "$LOG_PID" 2>/dev/null || true
else
    echo "No rsyslogd/syslogd found. Simulating: kill -0 on init (no-op)."
    kill -0 1 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Log_Tampering"
echo "    - Kill of log daemon"
echo "    tail -f /var/log/falco.log"
echo ""
