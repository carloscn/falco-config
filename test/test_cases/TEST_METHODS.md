# IDPS Test Method Steps

Detailed test method steps for each System-Level IDPS test case. Execute with Falco (or equivalent IDPS) running.

## Prerequisites

1. Falco installed: `sudo falco -c /etc/falco/falco.yaml &`
2. Log output: `tail -f /var/log/falco.log` (or stdout)
3. Root/sudo for tests that modify system paths

---

## Category 1: Abnormal Process Execution & Privilege Escalation

### SYS-PROC-001: Unexpected uid/gid identity

**Steps:**
1. Start Falco and tail logs
2. Run `runuser -u nobody -- id` or `sudo -u nobody id`
3. Verify Falco event: rule matching Abnormal_Process_Execution, uid/gid change

**Pass criteria:** Event contains pid, ppid, uid, gid, exe_path, cmdline

---

### SYS-PROC-002: Executable from writable directories

**Steps:**
1. Create script in /tmp: `echo '#!/bin/sh' > /tmp/test.sh; echo 'echo x' >> /tmp/test.sh; chmod +x /tmp/test.sh`
2. Execute: `/tmp/test.sh`
3. Verify Falco event: execve from /tmp

**Pass criteria:** Event contains exe_path with /tmp, cmdline, cwd

---

### SYS-PROC-003: Interactive shell spawn

**Steps:**
1. Run `bash -i -c "echo test; exit"`
2. Verify Falco event: interactive shell with non-approved parent

**Pass criteria:** Event contains bash -i, parent_exe, ppid

---

### SYS-PROC-004: Privilege escalation

**Steps:**
1. Run `sudo true` or `su -c id`
2. Verify Falco event: setuid/sudo/su execution

**Pass criteria:** Event contains exe (sudo/su), capabilities or uid change

---

### SYS-PROC-005: Unknown/non-baseline binary

**Steps:**
1. Copy binary to /tmp: `cp /bin/true /tmp/unknown_bin`
2. Execute: `/tmp/unknown_bin`
3. Verify Falco event: execve to non-whitelisted path

**Pass criteria:** Event contains exe_path not in baseline

---

## Category 2: Unexpected Modifications to Critical Files

### SYS-FILE-001: Writes to /etc auth files

**Steps:**
1. Run `sudo touch /etc/test_falco_xxx`
2. Run `cat /etc/shadow`
3. Verify Falco events: write to /etc, read of shadow

**Pass criteria:** File_Integrity_Violation, file_path in /etc

---

### SYS-FILE-002: Modifications to system binary dirs

**Steps:**
1. Run `sudo touch /usr/bin/test_falco_xxx` (may fail EROFS)
2. Verify Falco event: write attempt to /usr/bin

**Pass criteria:** File_Integrity_Violation, file_path in /usr/bin

---

### SYS-FILE-003: PAM/SSH/cron modifications

**Steps:**
1. Run `echo "# test" | sudo tee /etc/cron.d/test_falco_xxx`
2. Cleanup: `sudo rm /etc/cron.d/test_falco_xxx`
3. Verify Falco event: write to /etc/cron.d

**Pass criteria:** Persistence_Attempt, file_path in /etc/cron*

---

### SYS-FILE-004: systemd unit modifications

**Steps:**
1. Create unit: `echo "[Unit]\n[Service]\nExecStart=/bin/true" | sudo tee /etc/systemd/system/test-falco.service`
2. Cleanup: `sudo rm /etc/systemd/system/test-falco.service`
3. Verify Falco event: write to systemd unit

**Pass criteria:** Persistence_Attempt, file_path .service

---

## Category 3: Abnormal System Calls & Kernel Behavior

### SYS-KERN-001: Kernel module loading

**Steps:**
1. Run `sudo modprobe -n dummy` or `sudo insmod <module>`
2. Verify Falco event: init_module or modprobe

**Pass criteria:** Kernel_Integrity_Violation, exe=modprobe/insmod

---

### SYS-KERN-002: ptrace abuse

**Steps:**
1. Start background process: `sleep 10 &`
2. Run `strace -p <pid> -e trace=none`
3. Verify Falco event: ptrace attach

**Pass criteria:** Process_Injection, ptrace or strace

---

### SYS-KERN-003: capset operations

**Steps:**
1. Run `ping -c 1 127.0.0.1`
2. Run `sudo setcap cap_net_raw+ep /tmp/test_bin` (on copy of /bin/true)
3. Verify Falco event: capset or capability change

**Pass criteria:** Privilege_Escalation_Attempt, capset

---

### SYS-KERN-004: mount/umount operations

**Steps:**
1. Run `sudo mount -o remount,rw /`
2. Verify Falco event: mount remount

**Pass criteria:** Kernel_Integrity_Violation, mount_path=/

---

## Category 4: Abnormal Network Behavior

### SYS-NET-001: Non-baseline outbound connections

**Steps:**
1. Run `curl https://example.com` or `nc -zv 8.8.8.8 53`
2. Verify Falco event: outbound connection to non-whitelisted IP

**Pass criteria:** Command_And_Control, remote_ip, remote_port

---

### SYS-NET-002: Low port listening

**Steps:**
1. Run `nc -l 4444 &` then kill
2. Run `sudo nc -l 80 &` then kill (if port 80 free)
3. Verify Falco event: bind to low port

**Pass criteria:** Backdoor_Activity, local_port < 1024

---

### SYS-NET-003: SOCK_RAW creation

**Steps:**
1. Run `ping -c 1 127.0.0.1`
2. Or Python: `socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)`
3. Verify Falco event: raw socket creation

**Pass criteria:** Unauthorized_Network_Access, SOCK_RAW

---

### SYS-NET-004: AF_CAN socket creation

**Steps:**
1. Run Python: `socket.socket(29, 3, 1)` (AF_CAN, SOCK_RAW, CAN_RAW)
2. Verify Falco event: AF_CAN socket (on systems with CAN support)

**Pass criteria:** Unauthorized_Network_Access, socket_family=AF_CAN

---

## Category 5: Container / Process Escape

### SYS-CONT-001 to SYS-CONT-004

**Steps:** Require Docker. Run corresponding `SYS-CONT-*.sh` scripts.

**Pass criteria:** Container_Escape or Privilege_Escalation_Attempt with container_id

---

## Category 6: Resource Abuse & Hidden Threats

### SYS-RES-001: CPU/memory abuse

**Steps:**
1. Run `yes > /dev/null &` for 2–3 seconds, then kill
2. Verify Falco event: high CPU process (if rule exists)

---

### SYS-RES-002: Hidden process

**Steps:**
1. Copy sleep to /tmp: `cp /bin/sleep /tmp/hidden`
2. Run `/tmp/hidden 60 &`
3. Delete: `rm /tmp/hidden`
4. Verify Falco event: process from deleted binary

---

### SYS-RES-003: Fork bomb / mass spawning

**Steps:**
1. Run rapid fork: `for i in $(seq 1 20); do (sleep 2) & done; wait`
2. Verify Falco event: abnormal fork rate (if rule exists)

---

## Category 7: Log & Audit Integrity

### SYS-LOG-001: Log file tampering

**Steps:**
1. Run `echo test | sudo tee /var/log/test_falco.log`
2. Run `sudo truncate -s 0 /var/log/test_falco.log`
3. Cleanup: `sudo rm /var/log/test_falco.log`
4. Verify Falco event: write/truncate in /var/log

---

### SYS-LOG-002: Audit rule changes

**Steps:**
1. Run `sudo auditctl -l`
2. (Do not run auditctl -D in production)
3. Verify Falco event: auditctl execution (if rule exists)

---

### SYS-LOG-003: Log process termination

**Steps:**
1. Find rsyslogd: `pgrep rsyslogd`
2. Run `sudo kill -USR1 <pid>` (harmless signal)
3. Verify Falco event: signal to log daemon (if rule exists)

---

## Category 8: Physical Interface (USB)

### SYS-PHY-001 to SYS-PHY-003

**Steps:** Manual – insert USB Mass Storage, HID, or generic device. Detection via udev monitor.

**Pass criteria:** Physical_Device_Insertion event with vendor_id, product_id

---

## Running All Tests

```bash
cd /opt/falco-test  # or your test directory
for f in test_cases/SYS-*.sh; do
  echo "=== $f ==="
  bash "$f"
done
```
