#!/usr/bin/env python3

def debian_parse_updates(package_lines):
    """Parse Debian/Ubuntu package update lines"""
    packages = []
    for line in package_lines:
        if '/' in line and '[upgradable from:' in line:
            parts = line.split('/')
            if len(parts) >= 2:
                package_name = parts[0].strip()
                rest = parts[1]
                
                # Extract version info
                version_new = rest.split(' ')[0] if ' ' in rest else 'unknown'
                
                # Extract current version
                version_current = 'unknown'
                if '[upgradable from:' in rest:
                    version_current = rest.split('[upgradable from: ')[1].split(']')[0] if ']' in rest else 'unknown'
                
                # Determine if it's a security update
                is_security = 'security' in line.lower()
                
                packages.append({
                    'name': package_name,
                    'current_version': version_current,
                    'available_version': version_new,
                    'is_security': is_security,
                    'architecture': rest.split(' ')[1] if len(rest.split(' ')) > 1 else 'unknown',
                    'requires_reboot': 'kernel' in package_name.lower() or 'linux-image' in package_name.lower()
                })
    
    return packages

def redhat_parse_updates(package_lines):
    """Parse RedHat/CentOS/Rocky/Alma package update lines"""
    packages = []
    for line in package_lines:
        if line.strip() and not line.startswith('Last metadata') and not line.startswith('Loaded plugins'):
            parts = line.strip().split()
            if len(parts) >= 3:
                package_name = parts[0]
                available_version = parts[1]
                repository = parts[2] if len(parts) > 2 else 'unknown'
                
                # Determine if it's a security update based on repository name
                is_security = 'security' in repository.lower() or 'updates-security' in repository.lower()
                
                packages.append({
                    'name': package_name.split('.')[0] if '.' in package_name else package_name,
                    'current_version': 'installed',
                    'available_version': available_version,
                    'is_security': is_security,
                    'repository': repository,
                    'architecture': package_name.split('.')[-1] if '.' in package_name else 'unknown',
                    'requires_reboot': 'kernel' in package_name.lower()
                })
    
    return packages

class FilterModule(object):
    """Ansible filter plugin for updates parsing"""
    
    def filters(self):
        return {
            'debian_parse_updates': debian_parse_updates,
            'redhat_parse_updates': redhat_parse_updates,
        }