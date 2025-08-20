#!/usr/bin/env python3

def debian_parse_updates(package_lines):
    """Parse Debian/Ubuntu package update lines - Version de base"""
    packages = []
    
    for line in package_lines:
        line = line.strip()
        
        # Ignorer les lignes vides, d'en-tête et d'avertissement
        if not line or any(skip in line for skip in [
            'Listing', 'En train de lister', 'WARNING', 'AVERTISSEMENT',
            'Last metadata', 'Loaded plugins'
        ]):
            continue
            
        # Format attendu: package_name/repository version [upgradable from: current_version]
        # Ou format français: package_name/repository version [pouvant être mis à jour depuis : current_version]
        if ('/' in line and 
            ('[upgradable from:' in line or '[pouvant être mis à jour depuis :' in line)):
            try:
                # Séparer le nom du package et le reste
                parts = line.split('/', 1)
                if len(parts) < 2:
                    continue
                    
                package_name = parts[0].strip()
                rest = parts[1].strip()
                
                # Extraire la version disponible et le repository
                rest_parts = rest.split()
                if len(rest_parts) < 2:
                    continue
                    
                repository = rest_parts[0]
                version_new = rest_parts[1]
                
                # Extraire la version actuelle (support français et anglais)
                version_current = 'unknown'
                if '[upgradable from:' in line:
                    current_part = line.split('[upgradable from: ')[1]
                elif '[pouvant être mis à jour depuis :' in line:
                    current_part = line.split('[pouvant être mis à jour depuis : ')[1]
                else:
                    current_part = ''
                
                if ']' in current_part:
                    version_current = current_part.split(']')[0].strip()
                
                # Détection renforcée des mises à jour de sécurité
                repository_lower = repository.lower()
                
                is_security = any([
                    '-security' in repository_lower,
                    '/security' in repository_lower,
                    'security-updates' in repository_lower,
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
                continue
    
    return packages

def debian_parse_updates_improved(package_lines):
    """Alias pour la version améliorée - identique à debian_parse_updates"""
    return debian_parse_updates(package_lines)

def debian_parse_apt_get_sim(package_lines):
    """Parse la sortie de 'apt-get upgrade -s' (simulation)"""
    packages = []
    
    for line in package_lines:
        line = line.strip()
        
        if not line or not line.startswith('Inst '):
            continue
            
        try:
            # Format: Inst package_name [current_version] (new_version repository [architecture])
            # Enlever 'Inst ' du début
            line = line[5:]  # Remove 'Inst '
            
            # Séparer le nom du package du reste
            parts = line.split(' ', 1)
            if len(parts) < 2:
                continue
                
            package_name = parts[0]
            rest = parts[1]
            
            # Extraire les versions et le repository
            current_version = 'unknown'
            new_version = 'unknown'
            repository = 'unknown'
            architecture = 'unknown'
            
            # Pattern de parsing pour apt-get simulation
            if '[' in rest and ']' in rest and '(' in rest and ')' in rest:
                # Extraire la version actuelle entre []
                if '[' in rest:
                    current_start = rest.find('[') + 1
                    current_end = rest.find(']')
                    if current_end > current_start:
                        current_version = rest[current_start:current_end]
                
                # Extraire la nouvelle version et repo entre ()
                if '(' in rest:
                    paren_start = rest.find('(') + 1
                    paren_end = rest.find(')')
                    if paren_end > paren_start:
                        paren_content = rest[paren_start:paren_end]
                        paren_parts = paren_content.split()
                        if len(paren_parts) >= 2:
                            new_version = paren_parts[0]
                            repository = paren_parts[1]
                            if len(paren_parts) > 2:
                                architecture = paren_parts[2]
            
            # Détection de sécurité
            is_security = 'security' in repository.lower()
            
            # Détection redémarrage
            requires_reboot = any(
                kernel in package_name.lower() 
                for kernel in ['linux-', 'systemd', 'libc6']
            )
            
            package = {
                'name': package_name,
                'current_version': current_version,
                'available_version': new_version,
                'is_security': is_security,
                'repository': repository,
                'architecture': architecture,
                'requires_reboot': requires_reboot,
                'raw_line': line
            }
            
            packages.append(package)
            
        except Exception:
            continue
    
    return packages

def debian_enhance_security_detection(packages, security_lines):
    """Améliore la détection de sécurité en croisant avec d'autres sources"""
    enhanced_packages = []
    
    # Créer un set des packages de sécurité détectés dans security_lines
    security_packages = set()
    for line in security_lines:
        if 'Inst ' in line:
            try:
                package_name = line.split('Inst ')[1].split()[0]
                security_packages.add(package_name)
            except:
                continue
    
    for package in packages:
        # Copier le package original
        enhanced_package = package.copy()
        
        # Améliorer la détection de sécurité
        if not package.get('is_security', False):
            # Vérifier si le package est dans la liste des packages de sécurité
            if package['name'] in security_packages:
                enhanced_package['is_security'] = True
            
            # Vérifications supplémentaires
            repo_lower = package.get('repository', '').lower()
            if any(sec_term in repo_lower for sec_term in [
                'security', 'stable-security', 'updates-security'
            ]):
                enhanced_package['is_security'] = True
        
        enhanced_packages.append(enhanced_package)
    
    return enhanced_packages

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
    """Parse SUSE/OpenSUSE package update lines"""
    packages = []
    for line in package_lines:
        if line.strip():
            parts = line.strip().split()
            if len(parts) >= 3:
                package_name = parts[0]
                current_version = parts[1] if len(parts) > 1 else 'installed'
                available_version = parts[2] if len(parts) > 2 else 'unknown'
                
                # For SUSE, security updates typically come from specific repos
                # Since we don't have repository info in the line format, default to false
                # This should be enhanced by the enhance_security_detection function
                is_security = False
                
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
            'debian_parse_updates_improved': debian_parse_updates_improved,
            'debian_parse_apt_get_sim': debian_parse_apt_get_sim,
            'debian_enhance_security_detection': debian_enhance_security_detection,
            'redhat_parse_updates': redhat_parse_updates,
            'suse_parse_updates': suse_parse_updates,
            'extract_host_summary': extract_host_summary,
        }