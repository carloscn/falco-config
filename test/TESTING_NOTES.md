# Falco Testing Notes

## Default Rule Coverage

Falco's default rules are primarily focused on:

1. **Sensitive File Access** - ✅ Well covered
   - Reading `/etc/shadow`, `/etc/passwd`, etc.
   - Rules: "Read sensitive file untrusted", "Read sensitive file trusted after startup"

2. **System Directory Writes** - ✅ Well covered
   - Writing to `/etc` directory
   - Rule: "File below /etc opened for writing"

3. **Network Connections** - ✅ Well covered
   - Outbound connections, port scanning
   - Various network-related rules

4. **File Permission Modifications** - ⚠️ Limited coverage
   - Default rules may not detect all chmod operations
   - More likely to detect if modifying sensitive files (e.g., `/etc/shadow`)

5. **Process Injection** - ⚠️ Limited coverage
   - Requires custom rules for most injection techniques
   - Some ptrace operations may be detected

6. **Encoded Commands** - ⚠️ Limited coverage
   - Falco detects the underlying command execution, not the encoding
   - If encoded command reads `/etc/shadow`, it will trigger "Sensitive file opened" rule

7. **Mass File Access** - ⚠️ Limited coverage
   - Individual file accesses are detected
   - Pattern-based detection (mass access) requires custom rules

## Test Cases Expected Results

### High Success Rate (Default Rules)
- ✅ **Case 1**: Sensitive File Read - Should work
- ✅ **Case 2**: System Directory Write - Should work
- ✅ **Case 3**: Network Port Scan - Should work
- ✅ **Case 7**: Reverse Shell - Should work (network connections)
- ✅ **Case 10**: Network Connection Anomaly - Should work

### Medium Success Rate (May Need Sensitive File Access)
- ⚠️ **Case 5**: Suspicious Process - May work if script reads sensitive files
- ⚠️ **Case 8**: System File Modification - Should work (writes to /etc)
- ⚠️ **Case 9**: Encoded Commands - May work if command accesses sensitive files
- ⚠️ **Case 12**: Mass File Access - May work if accessing sensitive files

### Low Success Rate (Requires Custom Rules)
- ❌ **Case 4**: Privilege Escalation - Limited default coverage
- ❌ **Case 6**: File Permission Modification - Limited default coverage
- ❌ **Case 11**: Process Injection - Limited default coverage

## Improving Detection

### Option 1: Add Custom Rules

Create custom rules in `/etc/falco/falco_rules.local.yaml`:

```yaml
- rule: Suspicious Permission Modification
  desc: Detect suspicious file permission modifications
  condition: >
    evt.type = chmod and
    (fd.name contains /etc or fd.name contains /usr/bin or fd.name contains /usr/sbin)
  output: >
    Suspicious permission modification
    (user=%user.name process=%proc.name file=%fd.name mode=%evt.arg.mode)
  priority: WARNING
  tags: [file, permission]

- rule: Process Injection Attempt
  desc: Detect process injection attempts
  condition: >
    evt.type = ptrace and
    evt.arg.request = PTRACE_ATTACH
  output: >
    Process injection attempt detected
    (user=%user.name process=%proc.name target=%proc.pname)
  priority: WARNING
  tags: [process, injection]
```

### Option 2: Enable More Default Rules

Some default rules may be disabled. Check and enable them:

```bash
# List all rules
sudo falco -L

# Check which rules are enabled
sudo falco -L | grep enabled

# Rules are typically in /etc/falco/falco_rules.yaml
```

### Option 3: Adjust Rule Priorities

Some rules may have low priority and not be logged. Check rule priorities:

```bash
sudo falco -L | grep -E "priority|rule:"
```

## Testing Tips

1. **Focus on sensitive files**: Most test cases now include operations on `/etc/shadow` or `/etc/passwd` to increase detection likelihood

2. **Check Falco logs**: Always check `/var/log/falco.log` after running tests

3. **Verify Falco is running**: Use `pgrep -x falco` to ensure Falco is active

4. **Run tests as non-root**: Some rules only trigger for non-root users (container runs as `tester` user)

5. **Network tests work best**: Network-related rules have the best coverage

## Viewing Falco Rules

```bash
# List all rules
sudo falco -L

# List rules with descriptions
sudo falco -L | grep -A 5 "rule:"

# Search for specific rule types
sudo falco -L | grep -i "file\|network\|process"
```

## Custom Rule Examples

See Falco documentation for creating custom rules:
- https://falco.org/docs/rules/
- https://github.com/falcosecurity/rules
