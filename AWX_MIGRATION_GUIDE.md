# AWX Migration Guide

## Overview

This guide explains how to use the ansible-updates-reporting project with AWX/Ansible Tower, including the new AWX-compatible features that eliminate localhost dependencies.

## What's New

### AWX-Optimized Features
- **Automatic execution mode detection** - Detects AWX environment automatically
- **AWX artifacts support** - Reports stored as job artifacts
- **Fact caching** - Cross-play data sharing without local files
- **Container-based Excel generation** - No local Python dependencies
- **AWX native notifications** - Integrated with AWX notification system
- **Dual-mode execution** - Works in both AWX and traditional Ansible

### Files Added
- `vars/awx_mode.yml` - AWX execution mode detection and configuration
- `site_awx.yml` - AWX-optimized playbook
- `roles/awx_data_collector/` - AWX-compatible data collection role
- `roles/report_generator/tasks/awx_*.yml` - AWX-specific report generation
- `roles/notification_manager/tasks/awx_notify.yml` - AWX notification tasks
- `awx/job_templates/` - Pre-configured job templates
- `awx/workflows/` - Complete workflow templates
- `tests/awx_compatibility_test.yml` - Compatibility testing

## Quick Start

### 1. Import Project to AWX

```bash
# In AWX UI:
1. Projects → Add → SCM Type: Git
2. SCM URL: https://github.com/your-org/ansible-updates-reporting
3. Update on Launch: ✓
```

### 2. Create Credentials

```bash
# Required credentials:
1. Machine Credential - For SSH access to managed nodes
2. Vault Credential - If using encrypted variables
3. Custom Credential (optional) - For SMTP settings
```

### 3. Import Job Templates

```bash
# Option A: Manual creation
Use configurations from: awx/job_templates/updates_reporting_awx.yml

# Option B: AWX CLI
awx import < awx/job_templates/updates_reporting_awx.yml
```

### 4. Run AWX-Optimized Playbook

```bash
# Use the AWX-optimized playbook
Playbook: site_awx.yml

# Or traditional playbook (with limitations)
Playbook: site.yml
```

## Configuration

### Environment Variables (Automatic)

AWX automatically sets these environment variables:
- `AWX_HOST` - AWX server URL
- `JOB_ID` - Current job ID
- `AWX_ARTIFACTS_DIR` - Artifact storage directory
- `TOWER_OAUTH_TOKEN` - API authentication token

### Extra Variables

```yaml
# Force AWX mode (optional, auto-detected)
is_awx_environment: true

# Report formats
report_formats:
  - json
  - html
  - csv

# Notifications
send_notifications: true
webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Security thresholds
security_thresholds:
  critical_updates: 5
  security_updates: 10
```

## Key Differences from Traditional Mode

### Localhost Operations
**Traditional Mode:**
```yaml
- name: Generate report
  template:
    src: report.j2
    dest: /tmp/report.json
  delegate_to: localhost
```

**AWX Mode:**
```yaml
- name: Generate report (AWX-compatible)
  template:
    src: report.j2
    dest: "{{ awx_artifacts_dir }}/report.json"
  # No delegation needed
```

### Data Aggregation
**Traditional Mode:**
- Files written to localhost
- Fetch module for collection
- Manual aggregation

**AWX Mode:**
- Fact caching for data sharing
- AWX artifacts for storage
- Automatic aggregation

### Excel Generation
**Traditional Mode:**
- Requires Python packages on localhost
- Direct execution

**AWX Mode:**
- Container-based generation
- No local dependencies
- Fallback to CSV if containers unavailable

## Workflows

### Complete Updates Workflow
```yaml
1. Collect Updates (all hosts)
   ↓
2. Generate Reports (localhost)
   ↓
3. Send Notifications (if critical)
```

### Quick Security Check
```yaml
1. Quick Check (limited hosts)
   ↓
2. Analyze Results
   ↓
3. Conditional Alert
```

## Troubleshooting

### Issue: No artifacts generated
**Solution:** Ensure `AWX_ARTIFACTS_DIR` is writable:
```yaml
extra_vars:
  reports_storage_path: "/tmp/awx_artifacts"
```

### Issue: Excel generation fails
**Solution:** Check container runtime:
```bash
# Verify in job template:
container_runtime: podman  # or docker
```

### Issue: Notifications not sent
**Solution:** Use webhook as fallback:
```yaml
webhook_url: "https://your.webhook.url"
```

### Issue: Localhost delegation errors
**Solution:** Use AWX-optimized playbook:
```bash
Playbook: site_awx.yml  # Not site.yml
```

## Testing AWX Compatibility

Run the compatibility test:
```bash
ansible-playbook tests/awx_compatibility_test.yml
```

Expected output:
```
✓ AWX Environment Detection
✓ Artifact Directory Creation
✓ Fact Caching Compatibility
✓ Set Stats Functionality
✓ Container Runtime Detection
✓ Report Generation Paths
✓ Dual Mode Execution
✓ Localhost Delegation Control
```

## Best Practices

1. **Use AWX-optimized playbook** (`site_awx.yml`) for better performance
2. **Enable fact caching** in job templates for data persistence
3. **Configure webhooks** as backup notification method
4. **Set appropriate timeouts** for large infrastructures
5. **Use job template surveys** for runtime configuration
6. **Leverage AWX workflows** for complex pipelines
7. **Monitor job artifacts** for report access

## Migration Checklist

- [ ] Import project to AWX
- [ ] Create required credentials
- [ ] Import job templates
- [ ] Configure extra variables
- [ ] Test with small host group
- [ ] Verify artifact generation
- [ ] Configure notifications
- [ ] Set up scheduled jobs
- [ ] Document custom settings

## Support

For issues specific to AWX integration:
1. Check AWX job output for detailed errors
2. Review artifacts in AWX UI
3. Test with `awx_debug_mode: true`
4. Verify environment variables with `set_fact` debug tasks

## Limitations in AWX

While most features work, some limitations remain:
- Repository manager mode requires persistent storage
- Some Excel features need container runtime
- Custom Python filters must be in project
- Large reports may exceed artifact limits

## Future Enhancements

Planned improvements for AWX integration:
- Native AWX collection support
- Enhanced webhook integrations
- Metrics export to Prometheus
- Integration with AWX Analytics