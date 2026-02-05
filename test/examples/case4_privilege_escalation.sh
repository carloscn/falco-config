#!/usr/bin/env bash
# Test Case 4: Privilege Escalation Detection
# Test Objective: Verify Falco can detect suspicious privilege escalation attempts

set -e

echo "=========================================="
echo "Test Case 4: Privilege Escalation Detection"
echo "=========================================="
echo ""
echo "Test Objective: Verify Falco can detect privilege escalation operations"
echo ""

# Check if Falco is running
if ! pgrep -x falco > /dev/null; then
    echo "Warning: Falco process is not running, please start Falco first"
    echo "Start command: falco -c /etc/falco/falco.yaml & (in another terminal)"
    echo ""
    read -p "Continue test? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if current user is not root (required for privilege escalation test)
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: Running as root user. Privilege escalation test requires non-root user."
    echo "Please run this test as tester user (not root)"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Executing test operation: Using sudo to execute commands"
echo "Expected: Falco may detect privilege escalation related behavior"
echo ""

# Execute sudo operation
echo ">>> Executing: sudo whoami"
sudo whoami 2>&1 || {
    echo "Note: May need to configure sudo permissions"
}

echo ""
echo ">>> Executing: sudo -i (attempting to switch to root shell)"
echo ">>> Then executing: exit"
sudo -i <<EOF
whoami
exit
EOF

echo ""
echo ">>> Test operation completed"
echo ""
echo "Please check Falco log output for privilege escalation related warnings:"
echo "  - Process: process=sudo"
echo "  - User switching information"
echo "  - Command execution context"
echo ""
echo "If Falco is running in background, view logs: tail -f /var/log/falco.log"
echo ""
