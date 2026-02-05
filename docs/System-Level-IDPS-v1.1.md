# System-Level IDPS Detection Test Cases For Embedded Linux

## Overview

This document presents detailed **test cases** for a system-level Intrusion Detection and Prevention System (IDPS) on embedded Linux platforms used in automotive ECUs.

The design is strictly aligned with **UN Regulation No. 155 (R155)** cybersecurity requirements, focusing on:

- **7.2.2.2(g)**: Processes to monitor, detect, and respond to cyber-attacks, threats, and vulnerabilities, including continual effectiveness assessment.
- **7.2.2.2(h)**: Processes to provide relevant data (logs/telemetry) for analysis of attempted or successful cyber-attacks.
- **7.2.2.3**: Mitigation of threats and vulnerabilities within a reasonable timeframe based on risk categorization.
- **7.2.2.4**: Continual monitoring (including post-registration vehicles), analysis of threats from vehicle data/logs, while respecting privacy (e.g., data minimization, GDPR compliance).

**Scope**: Exclusively OS-level runtime behaviors (processes, files, system calls, network, kernel).  
**Out of Scope**: Vehicle-specific elements (CAN bus, ECU-to-ECU communication, diagnostics, OTA updates).

These test cases support:

- Real-time threat detection
- Event assessment and triage
- Structured log collection for attack analysis and traceability
- Continuous monitoring capability

**Design Improvements (per review feedback)**:

- Each detection item converted to standalone, scriptable **test case**
- Replaced vague terms ("unexpected", "non-whitelisted", "abnormal") with explicit **Expected Baseline** definitions
- Defined consistent **Evidence Fields** for output/logging (to align with ids-event-spec and enable automated validation/coverage analysis)
- Baseline to be concretized per vehicle program / ECU software release in collaboration with vehicle teams

## Event Output Schema (Aligned with ids-event-spec)

All detections shall produce structured events in the following format (JSON-compatible):

```json
{
  "rule_id": "SYS-PROC-001",
  "category": "Abnormal_Process_Execution",
  "severity": "high",
  "timestamp": "2026-02-02T13:30:00Z",
  "description": "Binary executed from non-baseline writable directory",
  "evidence": {
    "pid": 12345,
    "ppid": 1,
    "uid": 0,
    "gid": 0,
    "exe_path": "/tmp/malware.elf",
    "cmdline": "/tmp/malware.elf -c <http://c2.example.com>",
    "cwd": "/tmp",
    "parent_exe": "/bin/sh"
  }
}
```

Additional optional fields (if applicable): container_id, hash_status, remote_ip, remote_port, etc.

## Detection Test Cases

### Category 1: Abnormal Process Execution & Privilege Escalation

**Primary R155 Alignment**: 7.2.2.2(g), 7.2.2.2(h)

- **Test Case ID**: SYS-PROC-001  
    **Description**: Process executed with unexpected user/group identity  
    **Expected Baseline**: Processes execute under predefined uid/gid mappings per firmware (e.g., root=0 for init/system services; no arbitrary uid escalation or unknown users)  
    **Anomaly Condition**: Process launch with uid/gid not matching baseline for the executable or context  
    **Event Category**: Abnormal_Process_Execution  
    **Evidence Fields**: pid, ppid, uid, gid, exe_path, cmdline  
    **Severity**: High
- **Test Case ID**: SYS-PROC-002  
    **Description**: Executable launched from writable/non-standard directories  
    **Expected Baseline**: Execution restricted to read-only firmware paths (/bin, /sbin, /usr/bin, /usr/sbin, /libexec); prohibited from /tmp, /var/tmp, /dev/shm in production release  
    **Anomaly Condition**: execve syscall from prohibited writable directories  
    **Event Category**: Abnormal_Process_Execution  
    **Evidence Fields**: pid, exe_path, cmdline, cwd, uid  
    **Severity**: High
- **Test Case ID**: SYS-PROC-003  
    **Description**: Unexpected interactive shell spawn in non-login context  
    **Expected Baseline**: Interactive shells (e.g., bash -i, sh -i) only permitted from approved parents (sshd login sessions, specific systemd services)  
    **Anomaly Condition**: Shell process with interactive flags and non-approved parent process  
    **Event Category**: Privilege_Escalation_Attempt  
    **Evidence Fields**: pid, ppid, exe, cmdline, parent_exe, uid  
    **Severity**: High
- **Test Case ID**: SYS-PROC-004  
    **Description**: Privilege escalation attempts via setuid abuse or capabilities elevation  
    **Expected Baseline**: Only pre-approved setuid binaries (e.g., su, sudo, ping) and limited capset usage by known services  
    **Anomaly Condition**: Execution of non-baseline setuid binary or capset assigning high-risk capabilities (e.g., CAP_SYS_ADMIN)  
    **Event Category**: Privilege_Escalation_Attempt  
    **Evidence Fields**: pid, exe, cmdline, capabilities_before, capabilities_after, uid  
    **Severity**: Critical
- **Test Case ID**: SYS-PROC-005  
    **Description**: Execution of unknown/non-baseline binary  
    **Expected Baseline**: Only binaries in firmware whitelist (path + signature/hash per ECU release) permitted  
    **Anomaly Condition**: execve to path or binary not in current baseline whitelist  
    **Event Category**: Abnormal_Process_Execution  
    **Evidence Fields**: pid, exe_path, cmdline, hash_status, signature_status  
    **Severity**: Critical

### Category 2: Unexpected Modifications to Critical Files/Directories

**Primary R155 Alignment**: 7.2.2.2(g), 7.2.2.4

- **Test Case ID**: SYS-FILE-001  
    **Description**: Writes to core /etc authentication files  
    **Expected Baseline**: /etc/passwd, /etc/shadow, /etc/sudoers, /etc/ld.so.conf writable only by approved tools (e.g., passwd, useradd) in controlled scenarios  
    **Anomaly Condition**: Any write/open(O_WRONLY/O_APPEND/O_CREAT) to these files  
    **Event Category**: File_Integrity_Violation  
    **Evidence Fields**: pid, exe, file_path, open_flags, uid  
    **Severity**: Critical
- **Test Case ID**: SYS-FILE-002  
    **Description**: Modifications to system binary directories  
    **Expected Baseline**: /bin, /sbin, /usr/bin, /usr/sbin mounted read-only; no runtime modifications  
    **Anomaly Condition**: Write attempt to files in these directories  
    **Event Category**: File_Integrity_Violation  
    **Evidence Fields**: pid, exe, file_path, uid  
    **Severity**: Critical
- **Test Case ID**: SYS-FILE-003  
    **Description**: Modifications to PAM configuration, SSH keys, or cron jobs  
    **Expected Baseline**: Sensitive configs append-only or immutable; changes only via package manager/admin tools  
    **Anomaly Condition**: Write/create to /etc/pam.d/_, ~/.ssh/authorized_keys, /etc/cron_  
    **Event Category**: Persistence_Attempt  
    **Evidence Fields**: pid, file_path, exe, uid  
    **Severity**: High
- **Test Case ID**: SYS-FILE-004  
    **Description**: Modifications to systemd unit files  
    **Expected Baseline**: /etc/systemd/system, /lib/systemd/system read-only post-boot  
    **Anomaly Condition**: Write to .service, .timer, .conf files  
    **Event Category**: Persistence_Attempt  
    **Evidence Fields**: pid, file_path, exe, uid  
    **Severity**: High

### Category 3: Abnormal System Calls & Kernel Behavior

**Primary R155 Alignment**: 7.2.2.2(g), 7.2.2.2(h)

- **Test Case ID**: SYS-KERN-001  
    **Description**: Runtime kernel module loading  
    **Expected Baseline**: Module loading disabled in production or restricted to pre-loaded modules; no insmod/modprobe  
    **Anomaly Condition**: init_module or finit_module syscall invoked  
    **Event Category**: Kernel_Integrity_Violation  
    **Evidence Fields**: pid, exe, module_name (if available), uid  
    **Severity**: Critical
- **Test Case ID**: SYS-KERN-002  
    **Description**: ptrace system call abuse (process injection/debugging)  
    **Expected Baseline**: ptrace restricted; only allowed for self/approved debuggers on children  
    **Anomaly Condition**: PTRACE_ATTACH or POKETEXT on non-self process without baseline approval  
    **Event Category**: Process_Injection  
    **Evidence Fields**: pid, target_pid, exe, uid  
    **Severity**: High
- **Test Case ID**: SYS-KERN-003  
    **Description**: Abnormal capset/capget operations  
    **Expected Baseline**: capset usage limited to expected services  
    **Anomaly Condition**: capset assigning unexpected/high-risk capabilities  
    **Event Category**: Privilege_Escalation_Attempt  
    **Evidence Fields**: pid, exe, new_caps, uid  
    **Severity**: High
- **Test Case ID**: SYS-KERN-004  
    **Description**: Unexpected mount/umount operations (remount root rw)  
    **Expected Baseline**: Root filesystem mounted read-only; no remount to read-write. Only approved mounts (e.g., tmpfs for /tmp) are permitted.  
    **Anomaly Condition**: mount syscall with MS_REMOUNT and !MS_RDONLY on /, /boot, or /recovery partitions; or unauthorized mount/umount of critical filesystems.  
    **Event Category**: Kernel_Integrity_Violation  
    **Evidence Fields**: pid, exe, mount_path, mount_flags, source_device, uid  
    **Severity**: Critical  
    **Detection Mechanism**: Audit rules on mount/umount syscall

### Category 4: Abnormal Network Behavior

**Primary R155 Alignment**: 7.2.2.2(g), 7.2.2.4

- **Test Case ID**: SYS-NET-001  
    **Description**: Outbound connections to non-baseline IPs/ports  
    **Expected Baseline**: Connections only to project-defined endpoints (e.g., OTA/NTP servers); IP/port/domain whitelist per vehicle program  
    **Anomaly Condition**: connect/sendto to non-whitelisted destination  
    **Event Category**: Command_And_Control  
    **Evidence Fields**: pid, exe, remote_ip, remote_port, protocol, domain  
    **Severity**: High
- **Test Case ID**: SYS-NET-002  
    **Description**: Unexpected inbound listening on low ports  
    **Expected Baseline**: No bind to ports <1024 except explicitly approved services  
    **Anomaly Condition**: bind to low port by non-baseline process  
    **Event Category**: Backdoor_Activity  
    **Evidence Fields**: pid, exe, local_port, uid  
    **Severity**: High
- **Test Case ID**: SYS-NET-003  
    **Description**: Creation of SOCK_RAW sockets  
    **Expected Baseline**: Raw sockets (SOCK_RAW) are prohibited in production embedded systems (requires CAP_NET_RAW capability, typically dropped). They enable arbitrary packet crafting and bypass of network stack protections.  
    **Anomaly Condition**: socket() call with SOCK_RAW type (or SOCK_PACKET in older kernels), regardless of protocol.  
    **Event Category**: Unauthorized_Network_Access  
    **Evidence Fields**: pid, exe, socket_family, socket_type, protocol, uid, capabilities  
    **Severity**: Critical  
    **Detection Mechanism**: Audit syscall socket() with SOCK_RAW argument or seccomp filter denying raw sockets
- **Test Case ID**: SYS-NET-004  
    **Description**: Creation of AF_CAN (CAN bus) sockets  
    **Expected Baseline**: AF_CAN sockets are normally not used by general-purpose processes in most ECUs. Direct CAN socket creation should be restricted to dedicated CAN drivers/services (if present) and prohibited for user-space applications to prevent unauthorized CAN bus access or injection.  
    **Anomaly Condition**: socket() call with AF_CAN family (socket(PF_CAN, SOCK_RAW, CAN_RAW) or similar variants).  
    **Event Category**: Unauthorized_Network_Access  
    **Evidence Fields**: pid, exe, socket_family, socket_type, protocol, uid, interface  
    **Severity**: Critical  
    **Detection Mechanism**: Audit socket() syscall for AF_CAN family or seccomp policy blocking AF_CAN

### Category 5: Container / Process Escape Related (if container runtime is used)

**Primary R155 Alignment**: 7.2.2.2(g), 7.2.2.2(h)

- **Test Case ID**: SYS-CONT-001  
    **Description**: Container process accessing host sensitive paths  
    **Expected Baseline**: Containers run in isolated namespaces; no access to host /root, /proc, /sys, /dev from container processes  
    **Anomaly Condition**: Open/read/write to host-sensitive paths from container namespace  
    **Event Category**: Container_Escape  
    **Evidence Fields**: pid, container_id, exe, accessed_path, uid  
    **Severity**: Critical
- **Test Case ID**: SYS-CONT-002  
    **Description**: Privileged container startup  
    **Expected Baseline**: Containers start unprivileged (no --privileged flag); drop all capabilities except minimal set  
    **Anomaly Condition**: Container process starts with CAP_SYS_ADMIN or equivalent high privileges  
    **Event Category**: Container_Escape  
    **Evidence Fields**: pid, container_id, exe, capabilities, uid  
    **Severity**: Critical
- **Test Case ID**: SYS-CONT-003  
    **Description**: Mounting host sensitive directories inside container  
    **Expected Baseline**: No bind/mount of host /proc, /sys, /var/run/docker.sock, /etc inside container  
    **Anomaly Condition**: mount syscall inside container targeting host-sensitive paths  
    **Event Category**: Container_Escape  
    **Evidence Fields**: pid, container_id, mount_source, mount_target, uid  
    **Severity**: Critical
- **Test Case ID**: SYS-CONT-004  
    **Description**: Capabilities elevation inside container  
    **Expected Baseline**: Container capabilities restricted to baseline set; no elevation beyond startup config  
    **Anomaly Condition**: capset inside container assigning additional high-risk capabilities  
    **Event Category**: Privilege_Escalation_Attempt  
    **Evidence Fields**: pid, container_id, exe, new_caps, uid  
    **Severity**: High

### Category 6: Resource Abuse & Hidden Threats

**Primary R155 Alignment**: 7.2.2.2(g), 7.2.2.3

- **Test Case ID**: SYS-RES-001  
    **Description**: Abnormal CPU/memory consumption processes (e.g., cryptomining patterns)  
    **Expected Baseline**: Processes stay within expected resource limits per type (e.g., system services < 20% CPU sustained)  
    **Anomaly Condition**: Single process sustains high CPU (>80%) or memory (>threshold) over time window  
    **Event Category**: Resource_Abuse  
    **Evidence Fields**: pid, exe, cpu_usage_pct, mem_usage_mb, duration_sec  
    **Severity**: Medium
- **Test Case ID**: SYS-RES-002  
    **Description**: Hidden processes (unlinked file execution)  
    **Expected Baseline**: No processes execute from deleted/unlinked files in production  
    **Anomaly Condition**: /proc//exe links to "(deleted)" file  
    **Event Category**: Hidden_Process  
    **Evidence Fields**: pid, exe_path (deleted), cmdline, uid  
    **Severity**: High
- **Test Case ID**: SYS-RES-003  
    **Description**: Abnormal child process spawning (malicious script chains)  
    **Expected Baseline**: Normal process trees have limited depth and expected parents  
    **Anomaly Condition**: Deep or rapid fork chain (e.g., >10 levels or high spawn rate) from non-baseline parent  
    **Event Category**: Resource_Abuse  
    **Evidence Fields**: pid, ppid, exe, child_count, spawn_rate  
    **Severity**: Medium

### Category 7: Log & Audit Integrity

**Primary R155 Alignment**: 7.2.2.2(h), 7.2.2.4

- **Test Case ID**: SYS-LOG-001  
    **Description**: Detection of log file tampering (/var/log/\* deletion or modification)  
    **Expected Baseline**: Log files append-only or protected; no deletion/truncation by non-logger processes  
    **Anomaly Condition**: unlink, truncate, or write to /var/log/\* by unexpected process  
    **Event Category**: Log_Tampering  
    **Evidence Fields**: pid, exe, file_path, operation (unlink/truncate/write), uid  
    **Severity**: High
- **Test Case ID**: SYS-LOG-002  
    **Description**: Unexpected disabling or redirection of audit logs (auditd rule changes)  
    **Expected Baseline**: auditd rules immutable post-boot; no runtime -D (delete rules) or rule modifications  
    **Anomaly Condition**: auditctl -D or rule change attempts  
    **Event Category**: Log_Tampering  
    **Evidence Fields**: pid, exe, audit_command, uid  
    **Severity**: Critical
- **Test Case ID**: SYS-LOG-003  
    **Description**: Termination of log collection processes  
    **Expected Baseline**: Core loggers (syslogd, auditd, journald) not terminated in production  
    **Anomaly Condition**: kill or exit of log daemon processes by non-system user  
    **Event Category**: Log_Tampering  
    **Evidence Fields**: pid, target_pid, exe (killer), signal, uid  
    **Severity**: Critical

### Category 8: Physical Interface Attacks (USB Insertion)

**Primary R155 Alignment**: 7.2.2.2(g), 7.2.2.4

**Detection Approach**: Monitor USB hotplug events via udev (ACTION=="add"). Focus on unexpected insertions of Mass Storage (class 08) and HID (class 03) devices, which are common vectors for data exfiltration, persistence, or keystroke injection. In production ECU releases, USB interfaces are typically restricted or completely disabled except for explicitly whitelisted devices.

- **Test Case ID**: SYS-PHY-001  
    **Description**: Unexpected USB Mass Storage device insertion  
    **Expected Baseline**: In production mode, USB Mass Storage devices (bInterfaceClass == "08") are prohibited or restricted to a predefined whitelist of vendor:product IDs (and optionally serial numbers). Debug/factory modes may allow broader access for development purposes.  
    **Anomaly Condition**: udev event with ACTION=="add", SUBSYSTEM=="usb", bInterfaceClass=="08", and vendor:product ID not present in current baseline whitelist.  
    **Event Category**: Physical_Device_Insertion  
    **Evidence Fields**: action, subsystem, vendor_id, product_id, serial, bInterfaceClass, busnum, devnum, devpath  
    **Severity**: High  
    **Detection Mechanism**: udev monitor / custom udev rule with RUN+= script forwarding event to IDPS agent
- **Test Case ID**: SYS-PHY-002  
    **Description**: Unexpected USB HID device insertion (keyboard/mouse emulation)  
    **Expected Baseline**: USB HID devices (bInterfaceClass == "03") are disabled by default in production releases to prevent keystroke injection attacks. Only explicitly whitelisted HID devices (e.g., specific diagnostic tools) are permitted.  
    **Anomaly Condition**: udev event with ACTION=="add", SUBSYSTEM=="usb", bInterfaceClass=="03", and vendor:product ID not in baseline whitelist.  
    **Event Category**: Physical_Device_Insertion  
    **Evidence Fields**: action, vendor_id, product_id, serial, bInterfaceClass, busnum, devnum, devnode  
    **Severity**: Critical  
    **Detection Mechanism**: udev rule matching HID class, trigger alert to IDPS
- **Test Case ID**: SYS-PHY-003  
    **Description**: Generic unexpected USB device insertion (catch-all for non-whitelisted devices)  
    **Expected Baseline**: Only devices matching the per-release whitelist (vendor:product, class, serial combination) are allowed. All other USB insertions are considered anomalous to minimize risk from unknown peripherals.  
    **Anomaly Condition**: udev ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", and device attributes do not match current baseline whitelist.  
    **Event Category**: Physical_Device_Insertion  
    **Evidence Fields**: action, vendor_id, product_id, serial, bDeviceClass, bInterfaceClass, busnum, devnum, product, manufacturer  
    **Severity**: High  
    **Detection Mechanism**: Broad udev rule for usb_device add events + whitelist check in IDPS agent

**Baseline Maintenance Note**:

- USB whitelist (vendor:product IDs, device classes, serial patterns) maintained per vehicle program / ECU software release.
- Production mode: strict or zero USB allowance.
- Debug/factory mode: relaxed whitelist for development tools.
- False positive control: mode-aware rules + periodic whitelist review with vehicle teams.

## Test Scripts & Verification

Corresponding test scripts and detailed test method steps are provided in the `test/test_cases/` directory:

| Location | Description |
|----------|--------------|
| `test/test_cases/SYS-*.sh` | Shell scripts for each test case (IDs match document) |
| `test/README.md` | Script mapping and usage (IDPS section) |
| `test/test_cases/TEST_METHODS.md` | Detailed test method steps per case |

**Example:** Run `bash test/test_cases/SYS-PROC-001.sh` to simulate SYS-PROC-001 (unexpected uid/gid). Ensure Falco or equivalent IDPS is running and monitor logs for detection.

---

## Baseline Maintenance & False Positive Control

- All baselines/whitelists (binaries, paths, IPs/ports, capabilities, modules, etc.) shall be defined and maintained **per vehicle program / per ECU software release**.
- Collaborate with vehicle cybersecurity/software teams for concrete whitelist population.
- Support runtime modes (production/release vs. debug/factory) to relax rules in non-prod environments and reduce false positives.