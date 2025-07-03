#!/usr/bin/env python3

def debian_parse_updates(package_lines):
    """Parse Debian/Ubuntu package update lines - Version corrigée"""
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
                
                # Amélioration de la détection des mises à jour de sécurité
                is_security = (
                    'security' in line.lower() or 
                    'security-updates' in line.lower() or
                    '-security' in line.lower() or
                    '/security' in line.lower() or
                    'stable-security' in line.lower() or
                    'focal-security' in line.lower() or
                    'jammy-security' in line.lower() or
                    'bookworm-security' in line.lower()
                )
                
                packages.append({
                    'name': package_name,
                    'current_version': version_current,
                    'available_version': version_new,
                    'is_security': is_security,
                    'architecture': rest.split(' ')[1] if len(rest.split(' ')) > 1 else 'unknown',
                    'requires_reboot': 'kernel' in package_name.lower() or 'linux-image' in package_name.lower(),
                    'raw_line': line  # Ajout pour debugging
                })
    
    return packages

def redhat_parse_updates(package_lines):
    """Parse RedHat/CentOS/Rocky/Alma package update lines - Version corrigée"""
    packages = []
    for line in package_lines:
        if line.strip() and not line.startswith('Last metadata') and not line.startswith('Loaded plugins'):
            parts = line.strip().split()
            if len(parts) >= 3:
                package_name = parts[0]
                available_version = parts[1]
                repository = parts[2] if len(parts) > 2 else 'unknown'
                
                # Amélioration de la détection des mises à jour de sécurité
                is_security = (
                    'security' in repository.lower() or 
                    'updates-security' in repository.lower() or
                    'rhel-.*-security' in repository.lower() or
                    'epel-security' in repository.lower()
                )
                
                packages.append({
                    'name': package_name.split('.')[0] if '.' in package_name else package_name,
                    'current_version': 'installed',
                    'available_version': available_version,
                    'is_security': is_security,
                    'repository': repository,
                    'architecture': package_name.split('.')[-1] if '.' in package_name else 'unknown',
                    'requires_reboot': 'kernel' in package_name.lower(),
                    'raw_line': line  # Ajout pour debugging
                })
    
    return packages

def suse_parse_updates(package_lines):
    """Parse SUSE/OpenSUSE package update lines"""
    packages = []
    for line in package_lines:
        if line.strip():
            parts = line.strip().split()
            if len(parts) >= 3:
                package_name = parts[0]
                current_version = parts[1] if len(parts) > 1 else 'installed'
                available_version = parts[2] if len(parts) > 2 else 'unknown'
                
                # Determine if it's a security update (basic heuristic)
                is_security = 'security' in line.lower() or 'patch' in line.lower()
                
                packages.append({
                    'name': package_name,
                    'current_version': current_version,
                    'available_version': available_version,
                    'is_security': is_security,
                    'architecture': 'unknown',
                    'requires_reboot': 'kernel' in package_name.lower()
                })
    
    return packages

def extract_host_summary(host_data):
    """Extract summary information for a host"""
    return {
        'hostname': host_data.get('metadata', {}).get('hostname', 'unknown'),
        'fqdn': host_data.get('metadata', {}).get('fqdn', 'N/A'),
        'ip_address': host_data.get('metadata', {}).get('ip_address', 'N/A'),
        'distribution': host_data.get('system_info', {}).get('distribution', 'unknown'),
        'version': host_data.get('system_info', {}).get('version', 'unknown'),
        'total_updates': host_data.get('updates_summary', {}).get('total_updates', 0),
        'security_updates': host_data.get('updates_summary', {}).get('security_updates', 0),
        'critical_level': host_data.get('updates_summary', {}).get('critical_level', 'LOW'),
        'requires_reboot': host_data.get('updates_summary', {}).get('requires_reboot', False),
        'collection_timestamp': host_data.get('metadata', {}).get('collection_timestamp', 'unknown')
    }

class FilterModule(object):
    """Ansible filter plugin for updates parsing"""
    
    def filters(self):
        return {
            'debian_parse_updates': debian_parse_updates,
            'redhat_parse_updates': redhat_parse_updates,
            'suse_parse_updates': suse_parse_updates,
            'extract_host_summary': extract_host_summary,
        }