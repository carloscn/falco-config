# Falco IDPS Test Cases Documentation

## Test Objectives

This test suite aims to verify that Falco can effectively detect the following types of anomalies and high-risk behaviors in Ubuntu 22.04 environment:

1. **Sensitive File Access Detection** - Verify Falco can detect sensitive files (e.g., `/etc/shadow`) being opened by unauthorized programs
2. **System Directory Write Detection** - Verify Falco can capture write operations to critical system directories like `/etc`
3. **Network Anomaly Detection** - Verify Falco can identify port scanning, abnormal network connections, and other suspicious network behaviors
4. **Privilege Escalation Detection** - Verify Falco can detect suspicious privilege escalation attempts
5. **Suspicious Process Execution Detection** - Verify Falco can detect suspicious process execution and commands
6. **File Permission Modification Detection** - Verify Falco can detect suspicious file permission changes
7. **Reverse Shell Detection** - Verify Falco can detect reverse shell connection attempts
8. **System File Modification Detection** - Verify Falco can detect modifications to critical system files
9. **Encoded Command Execution Detection** - Verify Falco can detect base64/encoded command execution
10. **Network Connection Anomaly Detection** - Verify Falco can detect abnormal network connection patterns
11. **Process Injection Detection** - Verify Falco can detect process injection attempts
12. **Mass File Access Detection** - Verify Falco can detect mass file access patterns

## Test Environment

- **Operating System**: Ubuntu 22.04 (Docker container)
- **Falco Version**: Latest stable version
- **Driver Type**: modern eBPF (recommended) or kernel module
- **Rule Set**: Default rules + custom rules (if needed)
- **Test Directory**: `/opt/falco-test` (test folder is mounted in container)
- **Default User**: `tester` (non-root, for privilege escalation tests)

## Test Cases

### Test Case 1: Sensitive File Read Detection

**Test Objective**: Verify Falco can detect sensitive files being read

**Test Script**: `cases/case1_sensitive_file_opening.sh`

**Test Process**:
1. Ensure Falco is running
2. Execute test script, attempt to read `/etc/shadow` file
3. Observe Falco log output

**Expected Results**:
- Falco should trigger warning, rule name similar to: "Sensitive file opened for reading by non-trusted program"
- Log should contain the following key fields:
  - `file=/etc/shadow`
  - `process=cat` (or actual command used)
  - `user=tester` (or current user)
  - `evt_type=openat`
  - Timestamp and priority

**Execution Command**:
```bash
# Execute in container (test folder is mounted at /opt/falco-test)
cd /opt/falco-test
bash cases/case1_sensitive_file_opening.sh
```

---

### Test Case 2: System Directory Write Detection

**Test Objective**: Verify Falco can detect write operations to critical system directories

**Test Script**: `cases/case2_writing_etc.sh`

**Test Process**:
1. Ensure Falco is running
2. Execute test script, attempt to create or modify files in `/etc` directory
3. Observe Falco log output

**Expected Results**:
- Falco should trigger warning, rule name similar to: "File below /etc opened for writing"
- Log should contain:
  - `fd.name=/etc/testfile_falco` (or actual filename)
  - `process=touch` (or actual command)
  - `evt_type=openat` or `evt_type=open`
  - Write operation identifier

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case2_writing_etc.sh
```

---

### Test Case 3: Network Port Scan Detection

**Test Objective**: Verify Falco can detect network port scanning behavior

**Test Script**: `cases/case3_network_port_scan.sh`

**Test Process**:
1. Ensure Falco is running
2. Install nmap (if not installed)
3. Execute port scan operation
4. Observe Falco log output

**Expected Results**:
- Falco may trigger network-related warnings
- Log should contain:
  - `process=nmap`
  - Network connection information
  - Multiple SYN requests or abnormal connection patterns

**Note**: Some network behavior detection may require custom rules, as default rules may not include all network scan patterns.

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case3_network_port_scan.sh
```

---

### Test Case 4: Privilege Escalation Detection

**Test Objective**: Verify Falco can detect suspicious privilege escalation attempts

**Test Script**: `cases/case4_privilege_escalation.sh`

**Test Process**:
1. Ensure Falco is running
2. Execute sudo or su commands
3. Observe Falco log output

**Expected Results**:
- Falco may trigger privilege escalation-related warnings
- Log should contain:
  - `process=sudo` or `process=su`
  - User switching information
  - Command execution context

**Note**: This test requires running as non-root user (tester). The container runs as tester user by default.

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case4_privilege_escalation.sh
```

---

### Test Case 5: Suspicious Process Execution Detection

**Test Objective**: Verify Falco can detect suspicious process execution

**Test Script**: `cases/case5_suspicious_process.sh`

**Test Process**:
1. Ensure Falco is running
2. Execute some commands that may be considered suspicious (e.g., executing script from /tmp)
3. Observe Falco log output

**Expected Results**:
- Falco may trigger process execution-related warnings
- Log should contain:
  - Process path and command
  - Execution context
  - Suspicious behavior identifier

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case5_suspicious_process.sh
```

---

### Test Case 6: File Permission Modification Detection

**Test Objective**: Verify Falco can detect suspicious file permission modifications

**Test Script**: `cases/case6_file_permission_modification.sh`

**Test Process**:
1. Ensure Falco is running
2. Execute chmod operations to modify file permissions
3. Observe Falco log output

**Expected Results**:
- Falco may trigger file permission modification warnings
- Log should contain:
  - Process: process=chmod
  - File path and permission changes
  - Suspicious permission patterns (e.g., world-writable)

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case6_file_permission_modification.sh
```

---

### Test Case 7: Reverse Shell Detection

**Test Objective**: Verify Falco can detect reverse shell connection attempts

**Test Script**: `cases/case7_reverse_shell.sh`

**Test Process**:
1. Ensure Falco is running
2. Execute reverse shell connection attempts (simulated)
3. Observe Falco log output

**Expected Results**:
- Falco may trigger reverse shell-related warnings
- Log should contain:
  - Process: process=bash, nc, python
  - Network connections to suspicious ports
  - Shell execution with network redirection

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case7_reverse_shell.sh
```

---

### Test Case 8: System File Modification Detection

**Test Objective**: Verify Falco can detect modifications to critical system files

**Test Script**: `cases/case8_system_file_modification.sh`

**Test Process**:
1. Ensure Falco is running
2. Attempt to modify critical system files (e.g., /etc/passwd, /etc/hosts)
3. Observe Falco log output

**Expected Results**:
- Falco should trigger system file modification warnings
- Log should contain:
  - File: /etc/passwd, /etc/hosts, /usr/bin/*
  - Process: process=tee, touch
  - Write operations to system directories

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case8_system_file_modification.sh
```

---

### Test Case 9: Encoded Command Execution Detection

**Test Objective**: Verify Falco can detect base64/encoded command execution

**Test Script**: `cases/case9_encoded_command_execution.sh`

**Test Process**:
1. Ensure Falco is running
2. Execute base64 encoded commands
3. Observe Falco log output

**Expected Results**:
- Falco may trigger encoded command execution warnings
- Log should contain:
  - Process: process=base64, bash, python
  - Command: base64 decoding operations
  - Suspicious command execution patterns

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case9_encoded_command_execution.sh
```

---

### Test Case 10: Network Connection Anomaly Detection

**Test Objective**: Verify Falco can detect abnormal network connections

**Test Script**: `cases/case10_network_connection_anomaly.sh`

**Test Process**:
1. Ensure Falco is running
2. Create abnormal network connections (unusual ports, rapid connections)
3. Observe Falco log output

**Expected Results**:
- Falco may trigger network connection warnings
- Log should contain:
  - Process: process=curl, wget, bash
  - Network connections to unusual ports
  - Multiple rapid connection attempts

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case10_network_connection_anomaly.sh
```

---

### Test Case 11: Process Injection Detection

**Test Objective**: Verify Falco can detect process injection attempts

**Test Script**: `cases/case11_process_injection.sh`

**Test Process**:
1. Ensure Falco is running
2. Attempt process injection techniques (LD_PRELOAD, ptrace)
3. Observe Falco log output

**Expected Results**:
- Falco may trigger process injection warnings
- Log should contain:
  - Process: process=gdb, process manipulation
  - Library loading: LD_PRELOAD usage
  - Process memory access

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case11_process_injection.sh
```

---

### Test Case 12: Mass File Access Detection

**Test Objective**: Verify Falco can detect mass file access patterns

**Test Script**: `cases/case12_mass_file_access.sh`

**Test Process**:
1. Ensure Falco is running
2. Rapidly access multiple files
3. Observe Falco log output

**Expected Results**:
- Falco may trigger mass file access warnings
- Log should contain:
  - Process: process=cat, find, grep
  - Multiple file access in short time
  - File enumeration patterns

**Execution Command**:
```bash
cd /opt/falco-test
bash cases/case12_mass_file_access.sh
```

---

## Execution Workflow

### 1. Prepare Environment

```bash
# In project root directory
./scripts/setup_docker.sh

# Enter container (runs as tester user)
docker exec -it falco-test-ubuntu bash

# Install Falco (if not yet installed, requires sudo)
sudo /tmp/install_falco.sh
```

### 2. Start Falco

In container, choose one of the following methods to start Falco:

**Method 1: Using default configuration (recommended for testing)**
```bash
sudo falco -c /etc/falco/falco.yaml &
```

**Method 2: Using specified configuration file**
```bash
sudo falco -c /etc/falco/falco.yaml
```

**Method 3: Background run and output to file**
```bash
sudo falco -c /etc/falco/falco.yaml > /var/log/falco.log 2>&1 &
tail -f /var/log/falco.log
```

**Method 4: Test configuration (dry-run, only validate configuration)**
```bash
sudo falco --dry-run -c /etc/falco/falco.yaml
```

### 3. Run Test Cases

In another terminal, enter container and execute test script:

```bash
docker exec -it falco-test-ubuntu bash
cd /opt/falco-test
bash cases/case1_sensitive_file_opening.sh
```

### 4. View Falco Logs

**If Falco is running in foreground**: View output directly in terminal

**If Falco is running in background**: 
```bash
tail -f /var/log/falco.log
```

**View system logs**:
```bash
sudo journalctl -u falco -f  # If using systemd
```

### 5. Analyze Results

Compare actual output with expected results in `expected_outputs/` directory.

---

## Expected Log Format

Example of Falco standard log format:

```
2024-12-15T10:22:33.812791015+0000: Warning Sensitive file opened for reading by non-trusted program (file=/etc/shadow gparent=sudo ggparent=bash gggparent=tmux: evt_type=openat user=tester user_uid=1000 user_loginuid=1000 process=cat proc_exepath=/usr/bin/cat parent=sudo command=cat /etc/shadow terminal=34826 container_id=host container_name=host)
```

**Field Description**:
- **Timestamp**: ISO 8601 format
- **Priority**: Warning, Critical, Error, etc.
- **Rule Name**: Triggered Falco rule name
- **Event Details**: 
  - `file`: Accessed file path
  - `process`: Process name
  - `user`: Executing user
  - `evt_type`: Event type (openat, execve, etc.)
  - `command`: Full executed command
  - `container_id/container_name`: Container information (if in container environment)

---

## Troubleshooting

### Falco Cannot Start

1. Check if driver is correctly installed:
   ```bash
   sudo falco --list-syscall-events
   ```

2. Check permissions:
   ```bash
   # Ensure container has sufficient permissions
   docker exec -it falco-test-ubuntu ls -la /sys/kernel/debug
   ```

3. View detailed errors:
   ```bash
   sudo falco -v
   ```

### No Expected Events Detected

1. Check if rules are enabled:
   ```bash
   sudo falco -L  # List all rules
   ```

2. Validate rule syntax:
   ```bash
   sudo falco -c /etc/falco/falco.yaml -r /etc/falco/falco_rules.yaml --dry-run
   ```

3. Increase log verbosity:
   ```bash
   sudo falco -v -c /etc/falco/falco.yaml
   ```

---

## Testing Notes

**Important**: Not all test cases will trigger Falco's default rules. Falco's default rules primarily focus on:
- ✅ Sensitive file access (e.g., `/etc/shadow`)
- ✅ System directory writes (e.g., `/etc`)
- ✅ Network connections

Some behaviors (file permission modifications, process injection, etc.) may require custom rules to detect.

See [TESTING_NOTES.md](TESTING_NOTES.md) for detailed information about:
- Which test cases are most likely to succeed
- How to add custom rules for better detection
- Tips for improving test results

## Reference Resources

- [Falco Official Documentation](https://falco.org/docs/)
- [Falco Rules Repository](https://github.com/falcosecurity/rules)
- [Falco Best Practices](https://falco.org/docs/best-practices/)
