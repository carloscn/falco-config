#!/usr/bin/env bash
# Run all System-Level IDPS test scripts in batch (non-interactive)
# For use inside Docker: cd /opt/falco-test && bash test_cases/run_all_idps_tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Running all IDPS test scripts"
echo "=========================================="
echo ""
echo "Note: Falco should be running for detection. Start with: sudo falco -c /etc/falco/falco.yaml &"
echo ""

PASSED=0
FAILED=0
FAILED_LIST=""

for f in SYS-*.sh; do
    if [ -f "$f" ] && [ "$f" != "run_all_idps_tests.sh" ]; then
        echo "----------------------------------------"
        echo ">>> Running: $f"
        echo "----------------------------------------"
        # Fix CRLF line endings (for scripts edited on Windows)
        TMP_SCRIPT=$(mktemp)
        sed 's/\r$//' "$f" > "$TMP_SCRIPT" 2>/dev/null || cp "$f" "$TMP_SCRIPT"
        if bash "$TMP_SCRIPT" 2>&1; then
            rm -f "$TMP_SCRIPT"
            ((PASSED++)) || true
            echo "[PASS] $f"
        else
            rm -f "$TMP_SCRIPT"
            ((FAILED++)) || true
            FAILED_LIST="$FAILED_LIST $f"
            echo "[FAIL] $f"
        fi
        echo ""
    fi
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
if [ "$FAILED" -gt 0 ]; then
    echo "Failed scripts:$FAILED_LIST"
    exit 1
fi
echo ""
echo "All IDPS test scripts completed successfully."
exit 0
