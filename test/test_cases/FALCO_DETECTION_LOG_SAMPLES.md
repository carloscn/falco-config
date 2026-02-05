# Falco Detection Notes

## PASS Meaning

**[PASS]** in `run_all_idps_tests.sh` means the test script ran successfully (no errors), not that Falco detected the anomaly. Check Falco logs to confirm detection.

## Detection Coverage

All 30 IDPS cases can be detected by Falco via custom rules in `falco-config/falco_rules.local.yaml`.

## Compliance Logs

- **IDIADA review**: [IDIADA_COMPLIANCE_FALCO_LOGS.md](IDIADA_COMPLIANCE_FALCO_LOGS.md)
- **Raw logs**: `IDIADA_FALCO_LOGS/*.log` (one file per case)
- **Re-collect**: `.\test\test_cases\collect_logs_host.ps1` (requires Docker and Falco running)
