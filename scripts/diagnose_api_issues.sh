#!/bin/bash

# Script de diagnostic des APIs JSON
# Usage: ./diagnose_api_issues.sh [repository_server_ip]

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
REPO_SERVER="${1:-172.20.0.77}"
BASE_URL="http://${REPO_SERVER}"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to validate JSON
validate_json() {
    local url=$1
    local description=$2
    
    print_message "$BLUE" "Testing JSON: $description"
    print_message "$YELLOW" "URL: $url"
    
    # Test avec curl
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [[ "$response_code" == "200" ]]; then
        print_message "$GREEN" "✓ HTTP Response: $response_code"
        
        # Télécharger et valider le JSON
        local json_content
        json_content=$(curl -s "$url" 2>/dev/null || echo "")
        
        if [[ -n "$json_content" ]]; then
            # Vérifier avec jq si disponible
            if command -v jq &> /dev/null; then
                if echo "$json_content" | jq . > /dev/null 2>&1; then
                    print_message "$GREEN" "  ✓ Valid JSON format"
                    
                    # Vérifier la structure attendue
                    local has_timestamps
                    has_timestamps=$(echo "$json_content" | jq -r '.available_timestamps // empty' 2>/dev/null || echo "")
                    
                    if [[ -n "$has_timestamps" ]]; then
                        local timestamp_count
                        timestamp_count=$(echo "$json_content" | jq '.available_timestamps | length' 2>/dev/null || echo "0")
                        print_message "$BLUE" "  📊 Timestamps found: $timestamp_count"
                    else
                        print_message "$YELLOW" "  ⚠ No available_timestamps field found"
                    fi
                    
                else
                    print_message "$RED" "  ✗ Invalid JSON format"
                    echo "First 200 characters of response:"
                    echo "$json_content" | head -c 200
                    echo ""
                fi
            else
                # Fallback: simple validation with Python
                if command -v python3 &> /dev/null; then
                    if echo "$json_content" | python3 -m json.tool > /dev/null 2>&1; then
                        print_message "$GREEN" "  ✓ Valid JSON format (Python validation)"
                    else
                        print_message "$RED" "  ✗ Invalid JSON format (Python validation)"
                        echo "First 200 characters of response:"
                        echo "$json_content" | head -c 200
                        echo ""
                    fi
                else
                    print_message "$YELLOW" "  ⚠ Cannot validate JSON (no jq or python3 available)"
                fi
            fi
        else
            print_message "$RED" "  ✗ Empty response"
        fi
        
    else
        print_message "$RED" "✗ HTTP Error: $response_code"
    fi
    
    echo ""
}

# Function to test individual report files
test_report_files() {
    local format=$1
    local timestamp=$2
    
    print_message "$BLUE" "Testing report files for format: $format, timestamp: $timestamp"
    
    # Test différents types de fichiers selon le format
    case $format in
        "json")
            validate_json "$BASE_URL/$format/$timestamp/consolidated_report_$timestamp.json" "Consolidated JSON Report"
            validate_json "$BASE_URL/$format/$timestamp/index.json" "JSON Index"
            ;;
        "html")
            local html_response_code
            html_response_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$format/$timestamp/consolidated_report_$timestamp.html" || echo "000")
            print_message "$BLUE" "HTML Report: $html_response_code"
            ;;
        "excel")
            local excel_response_code
            excel_response_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$format/$timestamp/consolidated_report_$timestamp.xlsx" || echo "000")
            print_message "$BLUE" "Excel Report: $excel_response_code"
            ;;
    esac
    
    echo ""
}

# Main diagnostic execution
main() {
    print_message "$YELLOW" "=== Diagnostic des APIs JSON ==="
    print_message "$YELLOW" "Repository Server: $REPO_SERVER"
    print_message "$YELLOW" "Base URL: $BASE_URL"
    echo ""
    
    # Test 1: API principale
    validate_json "$BASE_URL/api.json" "Main API Catalog"
    
    # Test 2: APIs de format
    for format in "html" "json" "excel"; do
        validate_json "$BASE_URL/$format/api.json" "$format API Catalog"
    done
    
    # Test 3: Découverte des timestamps et test des fichiers
    print_message "$BLUE" "Discovering available timestamps..."
    
    if command -v jq &> /dev/null; then
        # Récupérer les timestamps depuis l'API JSON
        local timestamps
        timestamps=$(curl -s "$BASE_URL/json/api.json" | jq -r '.available_timestamps[]?.timestamp // empty' 2>/dev/null || echo "")
        
        if [[ -n "$timestamps" ]]; then
            print_message "$GREEN" "Found timestamps:"
            for timestamp in $timestamps; do
                print_message "$BLUE" "  - $timestamp"
                
                # Tester les fichiers pour ce timestamp
                for format in "json" "html" "excel"; do
                    test_report_files "$format" "$timestamp"
                done
                
                # Limiter aux 2 premiers timestamps pour éviter le spam
                break
            done
        else
            print_message "$YELLOW" "No timestamps found in JSON API"
        fi
    else
        print_message "$YELLOW" "Cannot discover timestamps (jq not available)"
    fi
    
    # Test 4: Liens symboliques 'latest'
    print_message "$BLUE" "Testing 'latest' symlinks..."
    for format in "html" "json" "excel"; do
        local latest_response_code
        latest_response_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$format/latest/" || echo "000")
        print_message "$BLUE" "Latest $format directory: $latest_response_code"
    done
    echo ""
    
    # Test 5: CORS headers
    print_message "$BLUE" "Testing CORS headers..."
    local cors_headers
    cors_headers=$(curl -s -I "$BASE_URL/api.json" | grep -i "access-control-allow-origin" || echo "")
    
    if [[ -n "$cors_headers" ]]; then
        print_message "$GREEN" "✓ CORS headers present: $cors_headers"
    else
        print_message "$YELLOW" "⚠ CORS headers not found"
    fi
    echo ""
    
    # Recommandations
    print_message "$YELLOW" "=== Recommandations ==="
    print_message "$BLUE" "Si des erreurs JSON sont détectées:"
    print_message "$BLUE" "1. Vérifiez les logs Apache/Nginx: /var/log/apache2/ ou /var/log/nginx/"
    print_message "$BLUE" "2. Relancez la génération des APIs: ansible-playbook site.yml --tags=\"repository,api\""
    print_message "$BLUE" "3. Vérifiez les permissions des fichiers: ls -la /var/www/reports/"
    echo ""
    print_message "$BLUE" "Pour debugger les templates Jinja2:"
    print_message "$BLUE" "1. Testez la validation JSON manuellement: python3 -m json.tool /var/www/reports/api.json"
    print_message "$BLUE" "2. Vérifiez les caractères spéciaux dans les données: grep -P '[^\\x00-\\x7F]' /var/www/reports/api.json"
    echo ""
    print_message "$GREEN" "Diagnostic terminé!"
}

# Execute main function
main "$@"