# IDIADA Compliance - System-Level IDPS Falco Detection Logs

**Doc version**: 1.0  
**Collection date**: 2026-02-05  
**Test environment**: Docker Ubuntu 22.04, Falco 0.43.0  
**Reference**: System-Level IDPS Detection Test Cases For Embedded Linux v1.1  

**Note**: Real Falco logs collected from `/var/log/falco.log` after each test case. Each case runs independently; logs are cleared before execution and captured immediately after.

---

## Collection Summary

| Case ID | Status | Description |
|---------|--------|-------------|
| SYS-CONT-001 | Detected | Container host path access |
| SYS-CONT-002 | Detected | Privileged container |
| SYS-CONT-003 | Detected | Host dir mount |
| SYS-CONT-004 | Detected | Container capabilities |
| SYS-FILE-001 | Detected | Write to /etc |
| SYS-FILE-002 | Detected | Write to /usr/bin |
| SYS-FILE-003 | Detected | Write to /etc/cron.d |
| SYS-FILE-004 | Detected | Write systemd unit |
| SYS-KERN-001 | Detected | Kernel module load |
| SYS-KERN-002 | Detected | ptrace abuse |
| SYS-KERN-003 | Detected | capset/setcap |
| SYS-KERN-004 | Detected | mount remount |
| SYS-LOG-001 | Detected | Log file tampering |
| SYS-LOG-002 | Detected | auditctl execution |
| SYS-LOG-003 | Detected | Log process termination |
| SYS-NET-001 | Detected | Non-baseline outbound |
| SYS-NET-002 | Detected | Low port listen |
| SYS-NET-003 | Detected | SOCK_RAW/ping |
| SYS-NET-004 | Detected | AF_CAN socket |
| SYS-PHY-001 | Detected | USB mass storage |
| SYS-PHY-002 | Detected | USB HID |
| SYS-PHY-003 | Detected | Generic USB |
| SYS-PROC-001 | Detected | Different user exec |
| SYS-PROC-002 | Detected | /tmp execution |
| SYS-PROC-003 | Detected | Interactive shell |
| SYS-PROC-004 | Detected | Privilege escalation |
| SYS-PROC-005 | Detected | Unknown binary |
| SYS-RES-001 | Detected | CPU/memory abuse |
| SYS-RES-002 | Detected | Hidden process |
| SYS-RES-003 | Detected | Fork bomb |

---

## Raw Log Files

All 30 case logs are in `test/test_cases/IDIADA_FALCO_LOGS/`:

| Files | Content |
|-------|---------|
| SYS-CONT-001.log ~ SYS-CONT-004.log | Container tests |
| SYS-FILE-001.log ~ SYS-FILE-004.log | File integrity tests |
| SYS-KERN-001.log ~ SYS-KERN-004.log | Kernel behavior tests |
| SYS-LOG-001.log ~ SYS-LOG-003.log | Log integrity tests |
| SYS-NET-001.log ~ SYS-NET-004.log | Network behavior tests |
| SYS-PHY-001.log ~ SYS-PHY-003.log | Physical interface tests |
| SYS-PROC-001.log ~ SYS-PROC-005.log | Process behavior tests |
| SYS-RES-001.log ~ SYS-RES-003.log | Resource abuse tests |

Each `.log` file contains:
- Collection timestamp
- Test script name
- Falco alerts (if any) or `# (No Falco detection for this case)`

**Collect**: Run `.\test\test_cases\collect_logs_host.ps1` (requires Docker and Falco running)
