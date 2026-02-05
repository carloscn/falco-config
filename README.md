# Falco IDPS Research Project

Falco IDPS research and experimentation on Ubuntu 22.04 Docker. Test cases aligned with UN R155 and System-Level IDPS specification.

## Project Structure

```
falco-config/
├── Dockerfile                 # Ubuntu 22.04 container image
├── docker-compose.yml         # Docker Compose config
├── scripts/                   # Automation scripts
│   ├── setup_docker.sh        # Build and start Docker
│   ├── install_falco.sh      # Falco installation
│   ├── test_falco.sh         # Falco test script
│   └── cleanup.sh            # Cleanup containers
├── falco-config/              # Falco config (mounted to /etc/falco)
│   └── falco_rules.local.yaml # Custom rules (IDPS 30 cases)
├── docs/                      # Documentation
│   └── System-Level-IDPS-v1.1.md  # IDPS test spec (R155)
├── test/                      # Test cases
│   ├── cases/                 # Generic tests case1-12
│   ├── test_cases/            # System-Level IDPS (SYS-* 30)
│   │   ├── SYS-*.sh           # Test scripts
│   │   ├── run_all_idps_tests.sh
│   │   ├── collect_logs_host.ps1   # Collect Falco logs (IDIADA)
│   │   ├── IDIADA_FALCO_LOGS/      # Real Falco logs per case
│   │   └── IDIADA_COMPLIANCE_FALCO_LOGS.md
│   └── expected_outputs/
├── QUICKSTART.md              # Quick start
└── README.md                  # This file
```

## Quick Start

### Step 1: Build Docker Environment

```bash
# Make scripts executable
chmod +x scripts/setup_docker.sh

# Build and start Docker container
./scripts/setup_docker.sh
```

### Step 2: Enter Container and Install Falco

```bash
# Enter container (runs as tester user by default)
docker exec -it falco-test-ubuntu bash

# Install Falco (requires sudo, tester user has sudo permissions)
sudo /tmp/install_falco.sh
```

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

### Step 4: Start Falco

```bash
# Start Falco in background
sudo falco -c /etc/falco/falco.yaml &

# View logs
tail -f /var/log/falco.log
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
- **Purpose**: Allows privilege escalation tests (case 4) to work properly
- **Sudo access**: Tester user has passwordless sudo for Falco installation

### Falco Configuration

- **Container plugin**: Automatically deleted (Falco 0.42+ has built-in container functionality)
- **File output**: Enabled by default, outputs to `/var/log/falco.log`
- **LD_PRELOAD**: Configured in docker-compose.yml (optional, for symbol resolution)

## Troubleshooting

### Docker Container Startup Failed

If you encounter:
```
ERROR: No such image: sha256:...
KeyError: 'ContainerConfig'
```

**Solution**:

Run cleanup script:
```bash
./scripts/cleanup.sh
```

Or manually clean:
```bash
# Stop and remove containers
docker-compose down

# Remove old container (if exists)
docker rm -f falco-test-ubuntu

# Rebuild and start
./scripts/setup_docker.sh
```

### GPG Key Verification Failed

If you encounter:
```
The following signatures couldn't be verified because the public key is not available: NO_PUBKEY 65106822B35B1B1F
```

**Solution**:

Re-run installation script (automatically fixes):
```bash
docker exec -it falco-test-ubuntu bash
sudo /tmp/install_falco.sh
```

### Falco Cannot Start (Docker Environment)

**Root Cause**:
Falco 0.42+ has container functionality as built-in bundled plugin, auto-loaded.
If `/etc/falco/config.d/falco.container_plugin.yaml` exists, it causes duplicate loading conflict.

**Solution 1 (Recommended): Delete container plugin config in config.d**:

```bash
# Delete container plugin config file
sudo rm -f /etc/falco/config.d/falco.container_plugin.yaml
sudo rm -f /etc/falco/config.d/falco.container_plugin.yaml.backup
sudo rm -f /etc/falco/config.d/falco.container_plugin.yaml.disabled

# Then run Falco directly
sudo falco
```

Installation script automatically deletes this config file.

**Solution 2: Use LD_PRELOAD** (if Solution 1 doesn't work):

1. **docker-compose automatically configures LD_PRELOAD**, you can run directly:
   ```bash
   sudo falco
   ```

2. **Manually specify LD_PRELOAD**:
   ```bash
   # Find libresolv.so path
   find /lib* -name libresolv.so*
   
   # Run with LD_PRELOAD
   LD_PRELOAD=/lib/x86_64-linux-gnu/libresolv.so.2 sudo falco
   ```

3. **Use test script**:
   ```bash
   /tmp/test_falco.sh
   ```

4. **Use wrapper script created by installation script**:
   ```bash
   /usr/local/bin/falco-wrapper.sh
   ```

**Issue Explanation**:
- Falco 0.42+ has built-in container functionality, auto-loads `libcontainer.so`
- `config.d/falco.container_plugin.yaml` conflicts with built-in plugin, must be deleted
- Installation script automatically deletes this config file

**Note**: 
- Installation script automatically deletes `config.d` container plugin config
- Docker environment has `LD_PRELOAD` environment variable configured (optional, usually not needed)
- If still having issues, can set `load_plugins: []` to not load any plugins

### Falco Running but No Logs

**Possible Causes**:
1. `file_output` is disabled
2. No events triggered (Falco only logs when rules are triggered)

**Solution**:

1. **Enable file_output** (installation script does this automatically):
   ```bash
   sudo sed -i '/^file_output:/,/^[[:space:]]*[a-z_]*output:/ {
       /enabled:/s/enabled:.*/enabled: true/
       /filename:/s|filename:.*|filename: /var/log/falco.log|
   }' /etc/falco/falco.yaml
   
   # Restart Falco
   sudo pkill falco
   sudo falco -c /etc/falco/falco.yaml &
   ```

2. **Run test cases to trigger events**:
   ```bash
   cd /opt/falco-test
   bash cases/case1_sensitive_file_opening.sh
   ```

3. **Check logs**:
   ```bash
   tail -f /var/log/falco.log
   ```

## Cleanup

To stop and remove containers:

```bash
./scripts/cleanup.sh
```

## Documentation

- [docs/System-Level-IDPS-v1.1.md](docs/System-Level-IDPS-v1.1.md) - IDPS test spec (R155)
- [test/README.md](test/README.md) - Test cases (case1-12 + SYS-* 30)
- [test/test_cases/IDIADA_COMPLIANCE_FALCO_LOGS.md](test/test_cases/IDIADA_COMPLIANCE_FALCO_LOGS.md) - IDIADA compliance

## License

This project is for research and educational purposes.
