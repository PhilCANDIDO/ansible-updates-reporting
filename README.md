# Ansible Updates Reporting

A comprehensive Ansible-based system for collecting, processing, and reporting package updates across multi-OS environments (Debian/Ubuntu, RedHat/CentOS/Rocky/Alma, SUSE/OpenSUSE). This system provides centralized visibility into security updates and package management across your infrastructure.

## Features

- **Multi-OS Support**: Works with Debian/Ubuntu, RedHat/CentOS/Rocky/Alma, and SUSE/OpenSUSE distributions
- **Security-Focused**: Identifies and prioritizes security updates with criticality levels
- **Multiple Report Formats**: Generates JSON, HTML, and Excel reports
- **Centralized Repository**: Optional web-based repository for storing and accessing reports
- **AWX/Tower Compatible**: Fully compatible with Ansible AWX and Tower environments
- **Connectivity Checking**: Pre-flight checks to handle unreachable hosts gracefully
- **Email Notifications**: Configurable alerts based on update thresholds
- **Retention Management**: Automatic cleanup of old reports

## Requirements

- Ansible 2.9 or higher
- Python 3.6 or higher
- Target hosts accessible via SSH
- For Excel reports: openpyxl, pandas, numpy (automatically installed)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ansible-updates-reporting.git
cd ansible-updates-reporting
```

2. Configure your inventory:
```bash
cp inventory/production.example inventory/production
# Edit inventory/production with your hosts
```

3. Configure settings:
```bash
cp vars/ansible-updates-reporting.yml.example vars/ansible-updates-reporting.yml
# Edit vars/ansible-updates-reporting.yml with your preferences
```

## Configuration

### Main Configuration File

Edit `vars/ansible-updates-reporting.yml`:

```yaml
# Report storage location
repository_base_path: /var/www/reports
control_node_reports_path: /tmp/ansible-reports

# Report formats to generate
report_formats:
  - json
  - html
  - excel

# Security thresholds for notifications
security_thresholds:
  critical_updates: 5
  security_updates: 10
  total_updates: 50

# Email notification settings
send_notifications: true
smtp_server: smtp.example.com
smtp_port: 587
smtp_from: ansible@example.com
notification_recipients:
  - admin@example.com

# Retention settings
retention_days: 30
max_archived_reports: 100
```

### Inventory Structure

```ini
[all]
web-server-01 ansible_host=192.168.1.10
db-server-01 ansible_host=192.168.1.20

[repository_managers]
srv-centreon ansible_host=192.168.1.100

[ansible]
srv-ansible01 ansible_host=192.168.1.5
```

## Usage

### Basic Execution

Run the full pipeline:
```bash
ansible-playbook -i inventory/production site.yml
```

### Specific Operations

Collect updates only:
```bash
ansible-playbook -i inventory/production site.yml --tags collect
```

Generate reports only:
```bash
ansible-playbook -i inventory/production site.yml --tags report
```

Update repository:
```bash
ansible-playbook -i inventory/production site.yml --tags repository
```

### AWX/Tower Integration

The project includes AWX-compatible configurations:

1. Import the playbook into AWX/Tower
2. Configure credentials for SSH access
3. Set up the inventory
4. Create a job template pointing to `site.yml`
5. Schedule regular executions

## Pipeline Workflow

1. **Pre-flight Connectivity Check**: Tests SSH connectivity to all hosts
2. **Setup Repository Manager**: Initializes the central repository (if configured)
3. **Collect Updates**: Gathers update information from each reachable host
4. **Generate Reports**: Creates consolidated reports in requested formats
5. **Update Repository**: Publishes reports to the central repository
6. **Send Notifications**: Sends email alerts based on thresholds

## Report Formats

### JSON Report
- Machine-readable format
- Complete update details for each host
- Suitable for integration with other systems

### HTML Report
- Web-based dashboard
- Interactive tables with sorting and filtering
- Visual indicators for critical hosts
- Responsive design for mobile viewing

### Excel Report
- Spreadsheet format with multiple sheets
- Summary statistics
- Detailed host information
- Ready for executive reporting

## Custom Filters

The project includes custom Jinja2 filters for parsing OS-specific update information:

- `debian_parse_updates`: Processes apt/apt-get output
- `redhat_parse_updates`: Handles yum/dnf output
- `suse_parse_updates`: Parses zypper output
- `debian_enhance_security_detection`: Cross-references security updates

## Error Handling

- **Unreachable Hosts**: Automatically detected and excluded from processing
- **Collection Failures**: Logged and reported without stopping the pipeline
- **Report Generation Errors**: Fallback mechanisms ensure partial reports are generated

## Security Considerations

- Uses SSH key authentication (recommended)
- No sensitive data stored in reports
- Supports read-only operations on target hosts
- Compatible with privilege escalation when needed

## Troubleshooting

### Common Issues

1. **Hosts marked as unreachable**:
   - Verify SSH connectivity: `ansible -i inventory/production all -m ping`
   - Check SSH keys and authentication

2. **Excel generation fails**:
   - Ensure Python dependencies are installed
   - Check for sufficient disk space

3. **AWX execution errors**:
   - Verify credentials in AWX
   - Check job template settings
   - Review execution environment compatibility

### Debug Mode

Run with increased verbosity:
```bash
ansible-playbook -i inventory/production site.yml -vvv
```

## Development

### Project Structure

```
ansible-updates-reporting/
├── site.yml                    # Main orchestration playbook
├── vars/
│   └── ansible-updates-reporting.yml  # Central configuration
├── roles/
│   ├── updates_collector/      # Collects update information
│   ├── report_generator/       # Generates reports
│   ├── repository_manager/     # Manages central repository
│   └── notification_manager/   # Handles email notifications
├── filter_plugins/
│   └── updates_filters.py      # Custom parsing filters
├── inventory/
│   └── production              # Inventory file
└── tests/                      # Test files
```

### Testing

Run molecule tests:
```bash
cd roles/updates_collector
molecule test
```

Run integration tests:
```bash
./scripts/test_new_features.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Open an issue on GitHub
- Check the CLAUDE.md file for development guidelines
- Review existing issues for solutions

## Acknowledgments

- Built with Ansible
- Optimized for AWX/Tower environments
- Designed for enterprise-scale deployments