#!/bin/bash

# Script to remove ACME certificate entries from acme.json
# Usage: ./remove-acme-cert.sh [path/to/acme.json]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default acme.json path (adjust as needed)
DEFAULT_ACME_FILE="/etc/traefik/certs/acme.json"

# Use provided path or default
ACME_FILE="${1:-$DEFAULT_ACME_FILE}"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to backup the acme.json file
backup_acme_file() {
    local backup_file="${ACME_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ACME_FILE" "$backup_file"
    print_color $GREEN "✓ Backup created: $backup_file"
}

# Function to list existing certificates
list_certificates() {
    print_color $BLUE "Current certificates in acme.json:"
    jq -r '.production.Certificates[]?.domain.main // empty' "$ACME_FILE" 2>/dev/null | sort | while read -r domain; do
        echo "  • $domain"
    done
    echo
}

# Function to search and remove certificate
remove_certificate() {
    local domain_to_remove=$1
    local temp_file=$(mktemp)
    
    # Check if domain exists
    local found=$(jq -r --arg domain "$domain_to_remove" '.production.Certificates[]? | select(.domain.main == $domain) | .domain.main' "$ACME_FILE" 2>/dev/null || true)
    
    if [[ -z "$found" ]]; then
        print_color $RED "❌ Domain '$domain_to_remove' not found in acme.json"
        rm -f "$temp_file"
        return 1
    fi
    
    print_color $YELLOW "Found certificate for: $found"
    
    # Remove the certificate entry
    jq --arg domain "$domain_to_remove" '
        .production.Certificates = [
            .production.Certificates[]? | 
            select(.domain.main != $domain)
        ]
    ' "$ACME_FILE" > "$temp_file"
    
    # Verify the JSON is valid
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$ACME_FILE"
        print_color $GREEN "✓ Certificate for '$domain_to_remove' removed successfully"
        
        # Fix file permissions (acme.json should be 600)
        chmod 600 "$ACME_FILE"
        print_color $GREEN "✓ File permissions restored (600)"
        
        return 0
    else
        print_color $RED "❌ Error: Generated JSON is invalid. Original file preserved."
        rm -f "$temp_file"
        return 1
    fi
}

# Main script
main() {
    print_color $BLUE "🔐 ACME Certificate Removal Tool"
    echo "================================"
    
    # Check if acme.json exists
    if [[ ! -f "$ACME_FILE" ]]; then
        print_color $RED "❌ Error: acme.json file not found at: $ACME_FILE"
        print_color $YELLOW "Usage: $0 [path/to/acme.json]"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_color $RED "❌ Error: jq is required but not installed"
        print_color $YELLOW "Install with: apt install jq (Debian/Ubuntu) or brew install jq (macOS)"
        exit 1
    fi
    
    print_color $BLUE "Using acme.json file: $ACME_FILE"
    echo
    
    # List existing certificates
    list_certificates
    
    # Prompt for domain to remove
    print_color $YELLOW "Enter the domain name to remove (e.g., test.lab.earles.io):"
    read -r domain_input
    
    # Trim whitespace
    domain_input=$(echo "$domain_input" | xargs)
    
    if [[ -z "$domain_input" ]]; then
        print_color $RED "❌ No domain entered. Exiting."
        exit 1
    fi
    
    print_color $YELLOW "You want to remove certificate for: $domain_input"
    print_color $YELLOW "This action will:"
    echo "  • Remove the certificate entry from acme.json"
    echo "  • Force Traefik to request a new certificate on next access"
    echo "  • Create a backup of the current acme.json file"
    echo
    
    print_color $YELLOW "Continue? [y/N]: "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color $BLUE "Operation cancelled."
        exit 0
    fi
    
    # Create backup
    backup_acme_file
    
    # Remove certificate
    if remove_certificate "$domain_input"; then
        echo
        print_color $GREEN "🎉 Certificate removal completed successfully!"
        print_color $BLUE "Next steps:"
        echo "  1. Restart Traefik to reload the configuration"
        echo "  2. Access the domain to trigger a new certificate request"
        echo "  3. Check Traefik logs for any certificate generation issues"
    else
        print_color $RED "❌ Certificate removal failed"
        exit 1
    fi
}

# Run main function
main "$@"