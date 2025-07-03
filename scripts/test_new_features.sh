#!/bin/bash

# Test script for new timestamped features
# Usage: ./test_new_features.sh [repository_server_ip]

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

# Function to test HTTP endpoint
test_endpoint() {
    local url=$1
    local description=$2
    local expected_type=$3
    
    print_message "$BLUE" "Testing: $description"
    print_message "$YELLOW" "URL: $url"
    
    # Test with curl
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [[ "$response_code" == "200" ]]; then
        print_message "$GREEN" "✓ SUCCESS: HTTP $response_code"
        
        # Check content type
        local content_type
        content_type=$(curl -s -I "$url" | grep -i "content-type" | cut -d: -f2 | tr -d ' \r\n' || echo "unknown")
        print_message "$BLUE" "  Content-Type: $content_type"
        
        # For JSON endpoints, try to parse JSON
        if [[ "$expected_type" == "json" ]]; then
            if curl -s "$url" | jq . > /dev/null 2>&1; then
                print_message "$GREEN" "  ✓ Valid JSON format"
            else
                print_message "$RED" "  ✗ Invalid JSON format"
            fi
        fi
        
    else
        print_message "$RED" "✗ FAILED: HTTP $response_code"
    fi
    
    echo ""
}

# Function to test directory listing
test_directory_listing() {
    local url=$1
    local description=$2
    
    print_message "$BLUE" "Testing directory: $description"
    print_message "$YELLOW" "URL: $url"
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [[ "$response_code" == "200" ]]; then
        print_message "$GREEN" "✓ SUCCESS: HTTP $response_code"
        
        # Count number of items in directory
        local item_count
        item_count=$(curl -s "$url" | grep -c "href=" || echo "0")
        print_message "$BLUE" "  Items found: $item_count"
        
    else
        print_message "$RED" "✗ FAILED: HTTP $response_code"
    fi
    
    echo ""
}

# Main test execution
main() {
    print_message "$YELLOW" "=== Testing Ansible Updates Reporting New Features ==="
    print_message "$YELLOW" "Repository Server: $REPO_SERVER"
    print_message "$YELLOW" "Base URL: $BASE_URL"
    echo ""
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_message "$YELLOW" "WARNING: jq not found. JSON validation will be skipped."
    fi
    
    # Test 1: Main landing page
    test_endpoint "$BASE_URL/" "Main repository landing page" "html"
    
    # Test 2: Main API endpoint
    test_endpoint "$BASE_URL/api.json" "Main API catalog" "json"
    
    # Test 3: Format-specific pages
    for format in "html" "json" "excel"; do
        test_directory_listing "$BASE_URL/$format/" "Format directory: $format"
        test_endpoint "$BASE_URL/$format/api.json" "API catalog for $format" "json"
    done
    
    # Test 4: Latest symlinks
    for format in "html" "json" "excel"; do
        test_directory_listing "$BASE_URL/$format/latest/" "Latest $format reports"
    done
    
    # Test 5: Try to find timestamped directories
    print_message "$BLUE" "Discovering timestamped directories..."
    
    # Get available timestamps from JSON API
    if command -v jq &> /dev/null; then
        local timestamps
        timestamps=$(curl -s "$BASE_URL/json/api.json" | jq -r '.available_timestamps[].timestamp' 2>/dev/null || echo "")
        
        if [[ -n "$timestamps" ]]; then
            print_message "$GREEN" "Found timestamps:"
            for timestamp in $timestamps; do
                print_message "$BLUE" "  - $timestamp"
                
                # Test timestamped directory
                for format in "html" "json" "excel"; do
                    test_directory_listing "$BASE_URL/$format/$timestamp/" "Timestamped $format reports: $timestamp"
                done
                
                # Only test first timestamp to avoid spam
                break
            done
        else
            print_message "$YELLOW" "No timestamps found. This might be expected if no reports have been generated yet."
        fi
    fi
    
    # Test 6: CORS headers
    print_message "$BLUE" "Testing CORS headers on API endpoints..."
    local cors_headers
    cors_headers=$(curl -s -I "$BASE_URL/api.json" | grep -i "access-control-allow-origin" || echo "")
    
    if [[ -n "$cors_headers" ]]; then
        print_message "$GREEN" "✓ CORS headers present: $cors_headers"
    else
        print_message "$YELLOW" "⚠ CORS headers not found (might not be configured)"
    fi
    echo ""
    
    # Test 7: Content compression
    print_message "$BLUE" "Testing content compression..."
    local compression
    compression=$(curl -s -H "Accept-Encoding: gzip" -I "$BASE_URL/" | grep -i "content-encoding" || echo "")
    
    if [[ -n "$compression" ]]; then
        print_message "$GREEN" "✓ Compression enabled: $compression"
    else
        print_message "$YELLOW" "⚠ Compression not detected"
    fi
    echo ""
    
    # Summary
    print_message "$YELLOW" "=== Test Summary ==="
    print_message "$GREEN" "Basic functionality tests completed."
    print_message "$BLUE" "To test the search functionality, open:"
    print_message "$BLUE" "  $BASE_URL/html/latest/ (or any timestamped directory)"
    print_message "$BLUE" "  And use the search box to filter hosts."
    echo ""
    print_message "$BLUE" "To test the API programmatically:"
    print_message "$BLUE" "  curl -X GET $BASE_URL/api.json | jq ."
    print_message "$BLUE" "  curl -X GET $BASE_URL/json/api.json | jq ."
    echo ""
    print_message "$GREEN" "Testing completed!"
}

# Execute main function
main "$@"