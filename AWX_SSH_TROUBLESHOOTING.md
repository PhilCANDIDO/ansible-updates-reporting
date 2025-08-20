# AWX SSH Troubleshooting Guide

## Common SSH Issues in AWX

### Issue 1: Host Key Verification Failed
**Error:** `Warning: Permanently added 'x.x.x.x' (ED25519) to the list of known hosts`

**Solutions:**

1. **In AWX Job Template**, add to Extra Variables:
```yaml
ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ansible_host_key_checking: false
```

2. **In Inventory Variables** (per host or group):
```yaml
ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
ansible_host_key_checking: false
```

3. **In AWX Settings** → Jobs → Extra Environment Variables:
```json
{
  "ANSIBLE_HOST_KEY_CHECKING": "False",
  "ANSIBLE_SSH_ARGS": "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}
```

### Issue 2: SSH Key Authentication Failed
**Error:** `Invalid/incorrect password: Permission denied, please try again`

**Solutions:**

1. **Verify SSH Credential in AWX:**
   - Navigate to Resources → Credentials
   - Edit your Machine Credential
   - Ensure the private key is in the correct format:
   ```
   -----BEGIN OPENSSH PRIVATE KEY-----
   [your ed25519 key content]
   -----END OPENSSH PRIVATE KEY-----
   ```

2. **For ED25519 keys**, ensure format is correct:
   ```bash
   # Generate ED25519 key if needed
   ssh-keygen -t ed25519 -C "awx-deploy"
   
   # Copy public key to servers
   ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@server
   ```

3. **Test manually from AWX container:**
   ```bash
   # Access AWX task container
   docker exec -it awx_task /bin/bash
   # or
   kubectl exec -it awx-task-pod -- /bin/bash
   
   # Test SSH connection
   ssh -i /tmp/awx_key -o StrictHostKeyChecking=no deploy@your-server
   ```

### Issue 3: SSH Banner Interference
**Error:** Long banner text appears in error messages

**Solutions:**

1. **Add to inventory variables:**
```yaml
ansible_ssh_common_args: "-o LogLevel=ERROR -o StrictHostKeyChecking=no"
ansible_ssh_pipelining: true
```

2. **Modify server SSH config** (if possible):
```bash
# /etc/ssh/sshd_config on target servers
PrintMotd no
Banner none  # or comment out Banner line
```

3. **Use pipelining** to reduce SSH connections:
```yaml
# In ansible.cfg or AWX settings
[ssh_connection]
pipelining = True
```

### Issue 4: Localhost Errors in AWX
**Error:** `[Errno 2] No such file or directory: b'hostname'`

**Solution:** Exclude localhost from test plays:
```yaml
hosts: all:!localhost
```

## AWX Credential Configuration

### Create Machine Credential Correctly:

1. **Name:** Deploy User SSH Key
2. **Credential Type:** Machine
3. **Username:** deploy
4. **SSH Private Key:** (paste your private key)
5. **Privilege Escalation Method:** sudo
6. **Privilege Escalation Username:** root (if needed)

### Test Credential:
```yaml
# Test playbook
---
- name: Test AWX SSH
  hosts: all:!localhost
  gather_facts: no
  tasks:
    - name: Test connection
      ping:
      register: result
    
    - name: Show result
      debug:
        var: result
```

## Inventory Configuration for AWX

### Basic Inventory with SSH Settings:
```ini
[servers]
srv-ansible01 ansible_host=10.1.8.132
ns1 ansible_host=10.1.8.177
ns2 ansible_host=10.1.8.178

[servers:vars]
ansible_user=deploy
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_host_key_checking=false
ansible_ssh_pipelining=true
```

### YAML Inventory Format:
```yaml
all:
  children:
    servers:
      hosts:
        srv-ansible01:
          ansible_host: 10.1.8.132
        ns1:
          ansible_host: 10.1.8.177
      vars:
        ansible_user: deploy
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
        ansible_host_key_checking: false
```

## AWX Job Template Settings

### Recommended Settings:
- **Enable Privilege Escalation:** Only if needed for tasks
- **Verbosity:** 1 (Debug) for troubleshooting
- **Extra Variables:**
```yaml
ansible_host_key_checking: false
ansible_ssh_pipelining: true
ansible_ssh_retries: 3
```

## Testing Connection in AWX

1. **Create Test Job Template:**
   - Name: Connection Test
   - Playbook: `quick_test_awx.yml`
   - Inventory: Your inventory
   - Credentials: Your SSH credential

2. **Run with Limited Scope:**
   - Use Limit field: `srv-ansible01` (test one host first)

3. **Check Job Output:**
   - Look for specific error messages
   - Verify credential is being used
   - Check for SSH banner issues

## Debug Commands

### From AWX Container:
```bash
# Test ansible connection
ansible -i /tmp/inventory all -m ping -vvv

# Test specific host
ansible -i /tmp/inventory srv-ansible01 -m ping -u deploy --private-key=/tmp/key -vvv

# Check SSH config
ansible-config dump | grep -i ssh
```

### Environment Variables for AWX:
```bash
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
export ANSIBLE_PIPELINING=True
```

## Quick Fixes Checklist

- [ ] SSH key format is correct (ED25519 with proper headers)
- [ ] Username in credential matches server user
- [ ] Host key checking disabled in job template
- [ ] Inventory has correct ansible_host addresses
- [ ] No localhost in target hosts
- [ ] Pipelining enabled for performance
- [ ] SSH args configured to skip host key check
- [ ] Test with single host before running on all

## If All Else Fails

1. Create a custom execution environment with SSH config
2. Use custom credential type with SSH options
3. Pre-populate known_hosts in custom EE
4. Use jump host/bastion configuration if network restricted