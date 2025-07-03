#!/usr/bin/env python3

def debian_parse_updates(package_lines):
    """Parse Debian/Ubuntu package update lines - Version corrigée et renforcée"""
    packages = []
    
    for line in package_lines:
        line = line.strip()
        if not line or line.startswith('Listing') or line.startswith('WARNING'):
            continue
            
        # Format attendu: package_name/repository version [upgradable from: current_version]
        if '/' in line and '[upgradable from:' in line:
            try:
                # Séparer le nom du package et le reste
                parts = line.split('/', 1)
                if len(parts) < 2:
                    continue
                    
                package_name = parts[0].strip()
                rest = parts[1].strip()
                
                # Extraire la version disponible (premier élément après le repository)
                rest_parts = rest.split(' ')
                if len(rest_parts) < 1:
                    continue
                    
                # Le repository peut contenir des espaces, donc on cherche la version
                version_new = 'unknown'
                repository = 'unknown'
                
                # Chercher la version dans les premiers éléments
                for i, part in enumerate(rest_parts):
                    if part and not part.startswith('['):
                        if i == 0:
                            repository = part
                        elif version_new == 'unknown':
                            version_new = part
                            break
                
                # Extraire la version actuelle
                version_current = 'unknown'
                if '[upgradable from:' in line:
                    current_part = line.split('[upgradable from: ')[1]
                    if ']' in current_part:
                        version_current = current_part.split(']')[0].strip()
                
                # Détection renforcée des mises à jour de sécurité
                line_lower = line.lower()
                repository_lower = repository.lower()
                
                is_security = any([
                    'security' in line_lower,
                    'security-updates' in line_lower,
                    '-security' in repository_lower,
                    '/security' in repository_lower,
                    'stable-security' in repository_lower,
                    'oldstable-security' in repository_lower,
                    'testing-security' in repository_lower,
                    # Ubuntu specific
                    'focal-security' in repository_lower,
                    'jammy-security' in repository_lower,
                    'kinetic-security' in repository_lower,
                    'lunar-security' in repository_lower,
                    'mantic-security' in repository_lower,
                    'noble-security' in repository_lower,
                    # Debian specific
                    'bookworm-security' in repository_lower,
                    'bullseye-security' in repository_lower,
                    'buster-security' in repository_lower,
                ])
                
                # Détection des paquets nécessitant un redémarrage
                kernel_packages = [
                    'linux-image', 'linux-headers', 'linux-modules',
                    'systemd', 'init', 'udev', 'libc6', 'libssl'
                ]
                
                requires_reboot = any(
                    kernel_pkg in package_name.lower() 
                    for kernel_pkg in kernel_packages
                )
                
                # Extraire l'architecture si présente
                architecture = 'unknown'
                if ' ' in rest:
                    for part in rest_parts:
                        if part in ['amd64', 'i386', 'arm64', 'armhf', 'all']:
                            architecture = part
                            break
                
                package = {
                    'name': package_name,
                    'current_version': version_current,
                    'available_version': version_new,
                    'is_security': is_security,
                    'repository': repository,
                    'architecture': architecture,
                    'requires_reboot': requires_reboot,
                    'raw_line': line  # Pour debugging
                }
                
                packages.append(package)
                
            except Exception as e:
                # En cas d'erreur de parsing, on continue avec le package suivant
                # mais on peut logger l'erreur pour debugging
                continue
    
    return packages

def redhat_parse_updates(package_lines):
    """Parse RedHat/CentOS/Rocky/Alma package update lines - Inchangé"""
    packages = []
    for line in package_lines:
        if line.strip() and not line.startswith('Last metadata') and not line.startswith('Loaded plugins'):
            parts = line.strip().split()
            if len(parts) >= 3:
                package_name = parts[0]
                available_version = parts[1]
                repository = parts[2] if len(parts) > 2 else 'unknown'
                
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
                    'raw_line': line
                })
    
    return packages

def suse_parse_updates(package_lines):
    """Parse SUSE/OpenSUSE package update lines - Inchangé"""
    packages = []
    for line in package_lines:
        if line.strip():
            parts = line.strip().split()
            if len(parts) >= 3:
                package_name = parts[0]
                current_version = parts[1] if len(parts) > 1 else 'installed'
                available_version = parts[2] if len(parts) > 2 else 'unknown'
                
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
    """Extract summary information for a host - Inchangé"""
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