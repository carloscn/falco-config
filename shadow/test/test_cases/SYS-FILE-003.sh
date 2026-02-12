#!/usr/bin/env bash

set -e

echo "=========================================="
echo "SYS-FILE-003: PAM/SSH/cron modifications"
echo "=========================================="
echo ""
echo "Expected Baseline: Sensitive configs append-only or immutable."
echo "Anomaly Condition: Write to /etc/pam.d/*, ~/.ssh/authorized_keys, /etc/cron*."
echo "Evidence Fields: pid, file_path, exe, uid"
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

echo ">>> Executing: Attempt write to /etc/cron.d"
CRON_TEST="/etc/cron.d/test_falco_sys_file_003_$(date +%s)"
echo "# test" | sudo tee "$CRON_TEST" >/dev/null 2>&1 || true
sudo rm -f "$CRON_TEST" 2>/dev/null || true

echo ">>> Executing: Attempt write to PAM config (read-only test)"
if [ -w /etc/pam.d ]; then
    PAM_TEST="/etc/pam.d/test_falco_$(date +%s)"
    echo "# test" | sudo tee "$PAM_TEST" >/dev/null 2>&1 || true
    sudo rm -f "$PAM_TEST" 2>/dev/null || true
fi

echo ""
echo ">>> Verification: Check Falco logs for:"
echo "    - Persistence_Attempt"
echo "    - Write to /etc/pam.d, /etc/cron*, authorized_keys"
echo "    tail -f /var/log/falco.log"
echo ""
