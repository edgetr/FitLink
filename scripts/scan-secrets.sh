#!/bin/bash
#
# Secret Scanning Script for FitLink
# Scans staged files or all files for potential secrets/API keys
#
# Usage:
#   ./scripts/scan-secrets.sh          # Scan staged files (for pre-commit)
#   ./scripts/scan-secrets.sh --all    # Scan all tracked files (for CI)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Secret patterns to detect (regex)
# These patterns match common API key formats
PATTERNS=(
    # Generic API keys (32+ character alphanumeric strings assigned to variables)
    'api[_-]?key["\s]*[:=]["\s]*["\047][A-Za-z0-9_\-]{32,}["\047]'
    
    # Bearer tokens
    'Bearer\s+[A-Za-z0-9_\-\.]{20,}'
    
    # AWS Access Key ID
    'AKIA[0-9A-Z]{16}'
    
    # AWS Secret Access Key (40 character base64)
    '["\047][A-Za-z0-9/+=]{40}["\047]'
    
    # Google API Key
    'AIza[0-9A-Za-z_\-]{35}'
    
    # Firebase API Key
    'AIza[0-9A-Za-z_\-]{35}'
    
    # Generic secret patterns
    'secret[_-]?key["\s]*[:=]["\s]*["\047][A-Za-z0-9_\-]{16,}["\047]'
    
    # Private key headers
    '-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'
    
    # GitHub tokens
    'gh[pousr]_[A-Za-z0-9_]{36,}'
    
    # Slack tokens
    'xox[baprs]-[0-9A-Za-z\-]{10,}'
    
    # Stripe keys
    'sk_live_[0-9a-zA-Z]{24,}'
    'sk_test_[0-9a-zA-Z]{24,}'
    'rk_live_[0-9a-zA-Z]{24,}'
    'rk_test_[0-9a-zA-Z]{24,}'
    
    # OpenAI API Key
    'sk-[A-Za-z0-9]{48,}'
    
    # Generic password assignments
    'password["\s]*[:=]["\s]*["\047][^"\047]{8,}["\047]'
)

# Files/directories to exclude from scanning
EXCLUDES=(
    "*.sample"
    "*.example"
    "*.template"
    ".git/"
    "Pods/"
    "DerivedData/"
    "*.xcresult"
    "scripts/scan-secrets.sh"  # Don't scan this file
)

# Function to check if file should be excluded
should_exclude() {
    local file="$1"
    for exclude in "${EXCLUDES[@]}"; do
        if [[ "$file" == *"$exclude"* ]] || [[ "$file" == $exclude ]]; then
            return 0  # Should exclude
        fi
    done
    return 1  # Should not exclude
}

# Function to scan a file for secrets
scan_file() {
    local file="$1"
    local found=0
    
    # Skip if file should be excluded
    if should_exclude "$file"; then
        return 0
    fi
    
    # Skip if file doesn't exist
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    # Skip binary files
    if file "$file" | grep -q "binary"; then
        return 0
    fi
    
    for pattern in "${PATTERNS[@]}"; do
        # Use grep with extended regex, ignore case for some patterns
        if grep -EnI "$pattern" "$file" 2>/dev/null; then
            echo -e "${RED}POTENTIAL SECRET FOUND${NC} in $file"
            echo "  Pattern matched: $pattern"
            found=1
        fi
    done
    
    return $found
}

# Main execution
main() {
    local scan_all=false
    local files_to_scan=()
    local secrets_found=0
    
    # Parse arguments
    if [[ "$1" == "--all" ]]; then
        scan_all=true
    fi
    
    echo -e "${YELLOW}FitLink Secret Scanner${NC}"
    echo "========================================"
    
    # Get files to scan
    if $scan_all; then
        echo "Scanning all tracked files..."
        while IFS= read -r -d '' file; do
            files_to_scan+=("$file")
        done < <(git ls-files -z 2>/dev/null || find . -type f -print0)
    else
        echo "Scanning staged files..."
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                files_to_scan+=("$file")
            fi
        done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
    fi
    
    if [[ ${#files_to_scan[@]} -eq 0 ]]; then
        echo -e "${GREEN}No files to scan.${NC}"
        exit 0
    fi
    
    echo "Found ${#files_to_scan[@]} file(s) to scan"
    echo ""
    
    # Scan each file
    for file in "${files_to_scan[@]}"; do
        if ! scan_file "$file"; then
            secrets_found=1
        fi
    done
    
    echo ""
    echo "========================================"
    
    if [[ $secrets_found -eq 1 ]]; then
        echo -e "${RED}SECRETS DETECTED!${NC}"
        echo ""
        echo "Please review the findings above and:"
        echo "  1. Remove any real secrets from the code"
        echo "  2. Use environment variables or secure storage"
        echo "  3. Add false positives to the EXCLUDES list in this script"
        echo ""
        echo "If this is a false positive, you can bypass with:"
        echo "  git commit --no-verify"
        echo ""
        exit 1
    else
        echo -e "${GREEN}No secrets detected.${NC}"
        exit 0
    fi
}

main "$@"
