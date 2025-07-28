# Bash Development Standards

This document outlines the standards and best practices for Bash script development in this organization.

## Project Structure

```
ProjectName/
├── scripts/          # Main bash scripts
├── lib/              # Shared functions and libraries
├── config/           # Configuration files
├── tests/            # Test scripts (using bats or similar)
├── docs/             # Documentation
├── logs/             # Log files directory
└── README.md         # Project documentation
```

## Code Standards

### 1. Script Headers and Documentation
- **ALWAYS** include a detailed header comment at the top of every script
- Include: Purpose, Author, Usage, Parameters, Examples, Dependencies
- Use consistent header format with script metadata
- Document all functions with clear descriptions

### 2. Shebang and Options
- Use `#!/bin/bash` or `#!/usr/bin/env bash` for portability
- Set strict mode: `set -euo pipefail` at the beginning
- Use `set -x` for debugging when needed
- Consider `set -E` for better error handling with traps

### 3. Variable Management
- Use UPPER_CASE for environment variables and constants
- Use lowercase for local variables
- Quote all variable expansions: `"$variable"`
- Use `readonly` for constants
- Initialize variables with default values

### 4. Function Standards
- Use descriptive function names with underscores: `validate_input`
- Include local variable declarations: `local var_name`
- Return meaningful exit codes (0 for success, non-zero for errors)
- Document function parameters and return values
- Keep functions focused on single responsibility

### 5. Error Handling
- Use trap statements for cleanup: `trap cleanup EXIT`
- Check command exit codes explicitly when needed
- Provide meaningful error messages to stderr
- Use `|| { echo "Error"; exit 1; }` for critical commands
- Log errors appropriately

### 6. Input Validation
- Validate all command-line arguments
- Check for required dependencies and commands
- Verify file and directory existence before operations
- Sanitize user input to prevent injection attacks
- Use parameter expansion for safe defaults

### 7. Security Best Practices
- Never hardcode credentials or sensitive data
- Use secure temporary files: `mktemp`
- Set proper file permissions
- Validate and sanitize all external input
- Use `shellcheck` to identify security issues

### 8. Code Formatting
- Use 2-space indentation consistently
- Place `then` and `do` on same line as `if`/`while`
- Use consistent spacing around operators
- Keep lines under 120 characters
- Use blank lines to separate logical sections

### 9. Command Usage
- Prefer bash built-ins over external commands when possible
- Use `[[ ]]` instead of `[ ]` for tests
- Use `$()` instead of backticks for command substitution
- Use array variables for lists of items
- Use `printf` instead of `echo` for formatting

### 10. AI-Assisted Development Standards
- Use AI tools consistently with standardized prompts
- Validate all AI-generated code against these standards
- Review AI suggestions for security and performance implications
- Document AI tool usage in code comments when significant
- Maintain human oversight for all AI-generated code
- Use AI for scaffolding functions with proper documentation structure
- Leverage AI for code review and optimization suggestions

### 11. Advanced Security Framework
- Never hardcode credentials or sensitive data
- Use environment variables or secure configuration files for secrets
- Implement comprehensive input validation patterns
- Use least privilege principle for file operations
- Sanitize file paths and validate user input
- Conduct automated credential leak detection
- Perform security scanning on all scripts
- Implement audit trails for sensitive operations
- Use approved cryptographic functions only (gpg, openssl)
- Validate certificates and signatures
- Use secure temporary files with proper permissions
- Implement secure file deletion practices

### 12. Performance Guidelines
- Avoid unnecessary subprocess spawning
- Use built-in bash features over external commands when possible
- Implement efficient string processing techniques
- Use arrays effectively for data manipulation
- Optimize loop structures and avoid nested loops when possible
- Profile scripts using `time` and `strace` for performance bottlenecks
- Implement caching mechanisms for expensive operations
- Use parallel processing with `xargs -P` or `GNU parallel` when appropriate

### 13. Testing Requirements
- Write tests using bats (Bash Automated Testing System)
- Achieve minimum 80% code coverage (enforced)
- Include unit tests, integration tests, and security tests
- Test both success and failure scenarios
- Include edge cases and boundary conditions
- Test with different input types and sizes
- Include performance benchmarking tests
- Implement automated vulnerability testing
- Test compliance scenarios for regulatory requirements
- Use mock objects and stubs for external dependencies
- Validate error handling and edge cases

### 14. Compliance and Regulatory Standards
- Implement SOX compliance for financial data handling
- Follow GDPR requirements for personal data processing
- Adhere to HIPAA standards for healthcare information
- Maintain audit trails for all data access and modifications
- Implement data retention and deletion policies
- Document compliance procedures and controls
- Regular compliance validation and reporting
- Implement secure logging practices

### 15. Metrics and Quality Gates
- Zero shellcheck violations (Error/Warning levels)
- Minimum 80% bats test coverage (enforced)
- Maximum 30-second execution time for standard scripts
- 100% header documentation coverage
- Zero hardcoded credentials or secrets
- Performance benchmarks within acceptable thresholds
- All security scans must pass
- Code review approval required before merge
- Compliance validation for applicable scripts

### 16. Enterprise Integration Patterns
- Implement structured logging with correlation IDs
- Use configuration management for environment-specific settings
- Integrate with enterprise monitoring and alerting systems
- Follow deployment pipeline requirements
- Implement proper exception handling and reporting
- Use centralized configuration repositories
- Integrate with enterprise identity and access management
- Follow change management procedures
- Use standard exit codes and return values
- Implement proper signal handling for enterprise orchestration

## Required Tools and Standards

### Development Environment
- Bash 4.0+ (prefer 5.0+)
- shellcheck for static analysis
- bats for testing
- VS Code with Bash extension
- jq for JSON processing
- yq for YAML processing
- Enterprise logging modules
- Security scanning tools (bandit-like for bash)
- Performance profiling tools
- Git hooks for quality enforcement

### Code Quality
- Run `shellcheck` before committing (zero violations)
- Address all Error and Warning level issues
- Use `.shellcheckrc` for project-specific rules
- Follow Google Shell Style Guide principles
- Execute security scans on all code
- Validate performance benchmarks
- Verify compliance requirements
- Run automated credential leak detection
- Use git hooks for automated quality checks
- Implement continuous integration quality gates

### Version Control
- Use semantic versioning for script versions
- Write descriptive commit messages
- Create feature branches for new development
- Use pull requests for code review

## Template Usage

1. Copy the template structure
2. Rename files and directories appropriately
3. Update README.md with project-specific information
4. Follow the coding standards outlined above
5. Write tests for all functions
6. Run shellcheck and tests before committing

## Enforcement

- All scripts must pass shellcheck with zero violations
- All functions must have complete header documentation
- Minimum 80% test coverage required
- All security scans must pass
- Performance benchmarks must be met
- Code reviews are mandatory for all changes
- Compliance validation required for applicable code
- Automated testing must pass before merging
- AI-generated code requires human review and validation
- Quality gates enforced through CI/CD pipeline

## Example Commands

### Running Tests
```bash
# Run tests with coverage enforcement
bats tests/
bats --tap tests/ | tee test_results.tap
# Generate coverage report
bashcov bats tests/
```

### Code Analysis
```bash
# Full analysis with zero tolerance
shellcheck scripts/*.sh --severity=error,warning
shellcheck --external-sources --check-sourced scripts/*.sh
```

### Security Scanning
```bash
# Credential leak detection
grep -r "password\|secret\|key" --include="*.sh" scripts/
# Security linting
semgrep --config=bash-security scripts/
```

### Performance Benchmarking
```bash
# Performance validation
time ./scripts/performance_test.sh
# Memory usage analysis
/usr/bin/time -v ./scripts/memory_test.sh
```

### Compliance Validation
```bash
# Audit trail verification
./scripts/audit_compliance.sh
# Data handling compliance check
./scripts/validate_data_handling.sh
```

### Common Patterns

#### Script Template
```bash
#!/bin/bash
# Script: example.sh
# Purpose: Example script following standards
# Author: Your Name
# Version: 1.0.0

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

# Functions
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]
Description of what the script does.

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
EOF
}

cleanup() {
    # Cleanup code here
    [[ -n "${TEMP_FILE:-}" ]] && rm -f "$TEMP_FILE"
}

main() {
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
    
    # Main script logic here
}

# Set up cleanup trap
trap cleanup EXIT

# Run main function
main "$@"
```

#### Error Handling
```bash
# Check if command exists
if ! command -v git &> /dev/null; then
    echo "Error: git is required but not installed" >&2
    exit 1
fi

# Check file exists
if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found: $config_file" >&2
    exit 1
fi
```
