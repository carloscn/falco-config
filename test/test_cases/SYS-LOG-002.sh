#!/usr/bin/env bash
# SYS-LOG-002: Unexpected disabling or redirection of audit logs
# Document: System-Level IDPS Detection Test Cases For Embedded Linux v1.1
# Category 7: Log & Audit Integrity

set -e

echo "=========================================="
echo "SYS-LOG-002: Audit rule changes"
echo "=========================================="
echo ""
echo "Expected Baseline: auditd rules immutable post-boot."
echo "Anomaly Condition: auditctl -D or rule change attempts."
echo "Evidence Fields: pid, exe, audit_command, uid"
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

echo ">>> Executing: auditctl commands (list/delete rules)"
echo ""

if command -v auditctl &>/dev/null; then
    sudo auditctl -l 2>/dev/null || true
    # -D deletes all rules - only simulate in dry-run or skip
    echo "Note: auditctl -D would delete rules; not executing to avoid breaking audit."
else
    echo "auditctl not available on this system."
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Log_Tampering"
echo "    - auditctl rule modification"
echo "    tail -f /var/log/falco.log"
echo ""
