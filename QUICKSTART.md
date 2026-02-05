# Quick Start Guide

## One-Click Setup (Recommended)

```bash
# 1. Build and start Docker container
./scripts/setup_docker.sh

# 2. Enter container and install Falco (one-click, automatically handles all issues)
docker exec -it falco-test-ubuntu bash
sudo /tmp/install_falco.sh

# 3. Start Falco in container (new terminal)
docker exec -it falco-test-ubuntu bash
sudo falco -c /etc/falco/falco.yaml &

# 4. Run test cases (another new terminal)
docker exec -it falco-test-ubuntu bash
cd /opt/falco-test
bash cases/case1_sensitive_file_opening.sh
```

## Detailed Steps

### Step 1: Build Docker Environment

```bash
chmod +x scripts/setup_docker.sh
./scripts/setup_docker.sh
```

This will:
- Pull Ubuntu 22.04 image
- Build container with necessary dependencies
- Start container and configure necessary mounts

### Step 2: Install Falco

```bash
# Enter container (runs as tester user)
docker exec -it falco-test-ubuntu bash

# Run installation script (requires sudo)
sudo /tmp/install_falco.sh
```

Installation script will:
- Update system packages
- Install Falco dependencies
- Add Falco repository (or compile from source)
- Install Falco
- Configure Falco (delete container plugin config, enable file output)
- Configure LD_PRELOAD (optional)

**Installation Options**:
```bash
# Install stable version (default)
sudo /tmp/install_falco.sh

# Install latest version
sudo /tmp/install_falco.sh latest

# Compile from source (recommended, avoids version issues)
sudo /tmp/install_falco.sh compile

# Install specific version
sudo /tmp/install_falco.sh stable 0.42.0
```

### Step 3: Test Falco Installation

```bash
# Run test script
/tmp/test_falco.sh
```

This will:
- Delete container plugin config (if exists)
- Test Falco configuration
- Trigger test events and check logs

### Step 4: Start Falco

**Method 1: Background (Recommended)**:

```bash
# Start Falco in background
sudo falco -c /etc/falco/falco.yaml &

# View logs
tail -f /var/log/falco.log
```

**Method 2: Foreground**:

```bash
# Start Falco in foreground (press Ctrl+C to stop)
sudo falco -c /etc/falco/falco.yaml
```

**Method 3: Using wrapper script** (if created):

```bash
sudo /usr/local/bin/falco-wrapper.sh -c /etc/falco/falco.yaml &
```

### Step 5: Run Test Cases

In a **new terminal**:

```bash
# Enter container
docker exec -it falco-test-ubuntu bash

# Run test cases (test folder is mounted at /opt/falco-test)
cd /opt/falco-test
bash cases/case1_sensitive_file_opening.sh
```

In the Falco terminal, you should see detected anomaly behavior logs.

## Important Notes

### Container User

- **Default user**: `tester` (non-root)
- **Sudo access**: Passwordless sudo for Falco installation
- **Purpose**: Allows privilege escalation tests (case 4) to work properly

### Falco Configuration

- **Container plugin config**: Automatically deleted during installation
- **File output**: Enabled by default (`/var/log/falco.log`)
- **LD_PRELOAD**: Configured in docker-compose.yml (optional)

## Troubleshooting

### Falco Cannot Start

1. **Check if container plugin config exists**:
   ```bash
   ls -la /etc/falco/config.d/falco.container_plugin.yaml
   ```
   If exists, delete it:
   ```bash
   sudo rm -f /etc/falco/config.d/falco.container_plugin.yaml
   ```

2. **Test configuration**:
   ```bash
   sudo falco --dry-run -c /etc/falco/falco.yaml
   ```

3. **Check logs**:
   ```bash
   sudo journalctl -u falco -n 50
   ```

### No Logs in /var/log/falco.log

1. **Check file_output is enabled**:
   ```bash
   grep -A 3 "file_output:" /etc/falco/falco.yaml
   ```
   Should show `enabled: true`

2. **Run test case to trigger events**:
   ```bash
   cd /opt/falco-test
   bash cases/case1_sensitive_file_opening.sh
   ```

3. **Check log file**:
   ```bash
   tail -f /var/log/falco.log
   ```

## IDPS Tests (30 SYS-* cases)

```powershell
# Run on host (Docker running, Falco started)
.\test\test_cases\collect_logs_host.ps1
```

See [test/README.md](test/README.md) and [IDIADA_COMPLIANCE_FALCO_LOGS.md](test/test_cases/IDIADA_COMPLIANCE_FALCO_LOGS.md).

## Next Steps

- [README.md](README.md) - Project overview
- [test/README.md](test/README.md) - Test cases
