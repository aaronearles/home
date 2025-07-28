# PowerShell Development Standards

This document outlines the standards and best practices for PowerShell script development in this organization.

## Project Structure

```
ProjectName/
├── Scripts/           # Main PowerShell scripts
├── Modules/          # Custom PowerShell modules
├── Tests/            # Pester tests
├── Docs/             # Documentation
├── Config/           # Configuration files
└── README.md         # Project documentation
```

## Code Standards

### 1. Comment-Based Help (CBH)
- **ALWAYS** include detailed Comment-Based Help at the top of every script and function
- Include: Synopsis, Description, Parameter descriptions, Examples, Notes, and Author
- Use proper CBH keywords: .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE, .NOTES, .AUTHOR

### 2. Parameter Splatting
- **ALWAYS** use splatting when a command has more than two parameters
- Use descriptive hashtable variable names ending in "Params" or "Splat"
- Format splatting with proper indentation

### 3. Error Handling
- Use `try-catch-finally` blocks for error-prone operations
- Set `$ErrorActionPreference = 'Stop'` at script level when appropriate
- Provide meaningful error messages
- Log errors appropriately

### 4. Naming Conventions
- Use approved PowerShell verbs (Get-Verb for list)
- Use PascalCase for function names: `Get-UserData`
- Use PascalCase for variables: `$UserList`
- Use UPPER_CASE for constants: `$MAX_RETRIES`
- Use descriptive names, avoid abbreviations
- Always use full command names (no aliases like `gps` instead of `Get-Process`)
- Always use full parameter names (avoid abbreviated parameters)

### 5. Code Formatting
- Use 4-space indentation (no tabs)
- Place opening braces on same line as statement (One True Brace Style)
- Closing braces should be at the beginning of a line
- Use blank lines to separate logical sections
- Limit lines to 115 characters
- Use consistent spacing around operators
- Use single space around parameters and operators
- Avoid unnecessary spaces inside parentheses or square brackets
- End each file with a single blank line
- Surround function definitions with two blank lines

### 6. Functions and Modules
- Keep functions focused on single responsibility
- Always start functions with `[CmdletBinding()]`
- Use explicit `param()`, `begin`, `process`, `end` block order
- Include proper parameter attributes: `[Parameter(Mandatory)]`
- Return objects, not formatted text
- Use pipeline-friendly functions
- Avoid using semicolons as line terminators
- Small scriptblocks can be on a single line as exception

#### Begin/Process/End Block Usage
- Use all three blocks for clarity and proper pipeline handling:
  ```powershell
  function Get-Something {
      [CmdletBinding()]
      param (
          [Parameter(ValueFromPipeline)]
          [string[]]$InputObject
      )
      
      begin {
          # Run once at start
          # Initialize variables, create connections
          $results = @()
      }
      
      process {
          # Runs for each pipeline input
          # Process each $InputObject
          foreach ($item in $InputObject) {
              $results += Process-Item $item
          }
      }
      
      end {
          # Run once at end
          # Clean up, close connections
          # Return final results
          $results
      }
  }
  ```
- **Begin Block**: Use for one-time initialization
  - Set up variables
  - Create database connections
  - Initialize arrays for results
- **Process Block**: Required for pipeline input
  - Process each input item individually
  - Use foreach loops for array inputs
  - Add to result collections
- **End Block**: Use for cleanup and final output
  - Close connections
  - Aggregate results
  - Return final objects

### 7. Path Usage Standards
- Use full, explicit paths when possible
- Avoid relative paths like `./README.md`
- Prefer using `$PSScriptRoot` for script-relative paths
- Avoid using `~` to represent home folder
- Sanitize file paths and validate user input

### 8. AI-Assisted Development Standards
- Use AI tools consistently with standardized prompts
- Validate all AI-generated code against these standards
- Review AI suggestions for security and performance implications
- Document AI tool usage in code comments when significant
- Maintain human oversight for all AI-generated code
- Use AI for scaffolding functions with proper CBH structure
- Leverage AI for code review and optimization suggestions

### 9. Advanced Security Framework
- Never hardcode credentials or sensitive data
- Use `SecureString` for passwords and integrate SecretManagement module
- Implement comprehensive input validation patterns
- Use least privilege principle
- Sanitize file paths and validate user input
- Conduct automated credential leak detection
- Perform security scanning on all scripts
- Implement audit trails for sensitive operations
- Use approved cryptographic functions only
- Validate certificates and signatures

### 10. Performance Guidelines
- Use `Where-Object` efficiently (avoid unnecessary filtering)
- Prefer `ForEach-Object` over `ForEach` for large datasets
- Use `StringBuilder` for string concatenation in loops
- Avoid `Write-Host` in functions (use `Write-Output` or `Write-Information`)

### 11. Testing Requirements
- Write Pester tests for all functions
- Achieve minimum 80% code coverage (enforced)
- Include unit tests, integration tests, and security tests
- Test both success and failure scenarios
- Include performance benchmarking tests
- Implement automated vulnerability testing
- Test compliance scenarios for regulatory requirements
- Use mock objects for external dependencies
- Validate error handling and edge cases

### 12. Documentation
- Maintain README.md with setup and usage instructions
- Document configuration requirements
- Include examples of common use cases
- Keep documentation up-to-date

### 13. Compliance and Regulatory Standards
- Implement SOX compliance for financial data handling
- Follow GDPR requirements for personal data processing
- Adhere to HIPAA standards for healthcare information
- Maintain audit trails for all data access and modifications
- Implement data retention and deletion policies
- Document compliance procedures and controls
- Regular compliance validation and reporting

### 14. Metrics and Quality Gates
- Zero PSScriptAnalyzer violations (Error/Warning levels)
- Minimum 80% Pester test coverage (enforced)
- Maximum 2-minute execution time for standard functions
- 100% CBH documentation coverage
- Zero hardcoded credentials or secrets
- Performance benchmarks within acceptable thresholds
- All security scans must pass
- Code review approval required before merge

### 15. Enterprise Integration Patterns
- Implement structured logging with correlation IDs
- Use configuration management for environment-specific settings
- Integrate with enterprise monitoring and alerting systems
- Follow deployment pipeline requirements
- Implement proper exception handling and reporting
- Use centralized configuration repositories
- Integrate with enterprise identity and access management
- Follow change management procedures

## Required Tools and Modules

### Development Environment
- PowerShell 5.1+ or PowerShell 7+
- VS Code with PowerShell extension
- PSScriptAnalyzer for code analysis
- Pester for testing
- SecretManagement module for credential handling
- PlatyPS for documentation generation
- Enterprise logging modules
- Security scanning tools
- Performance profiling tools

### Code Quality
- Run `Invoke-ScriptAnalyzer` before committing (zero violations)
- Address all Error and Warning level issues
- Use `.vscode/settings.json` for consistent formatting
- Execute security scans on all code
- Validate performance benchmarks
- Verify compliance requirements
- Run automated credential leak detection

### Version Control
- Use semantic versioning (SemVer)
- Write descriptive commit messages
- Create feature branches for new development
- Use pull requests for code review

## Template Usage

1. Copy the template structure
2. Rename files and folders appropriately
3. Update README.md with project-specific information
4. Follow the coding standards outlined above
5. Write tests for all functions
6. Run code analysis before committing

## Enforcement

- All code must pass PSScriptAnalyzer with zero violations
- All functions must have complete CBH documentation
- Minimum 80% test coverage required
- All security scans must pass
- Performance benchmarks must be met
- Code reviews are mandatory for all changes
- Compliance validation required for applicable code
- Automated testing must pass before merging
- AI-generated code requires human review and validation

## Example Commands

### Running Tests
```powershell
# Run tests with coverage enforcement
Invoke-Pester -Path ./Tests -CodeCoverage ./Scripts/*.ps1 -CoveragePercentTarget 80
```

### Code Analysis
```powershell
# Full analysis with zero tolerance
Invoke-ScriptAnalyzer -Path ./Scripts -Recurse -Settings PSGallery -Severity Error,Warning
```

### Security Scanning
```powershell
# Credential leak detection
Test-ScriptSecurity -Path ./Scripts -CheckCredentials -CheckSecrets
```

### Performance Benchmarking
```powershell
# Performance validation
Measure-ScriptPerformance -Path ./Scripts -MaxExecutionTime 120
```

### Building Documentation
```powershell
# Use PlatyPS for external help generation
New-ExternalHelp -Path ./Docs -OutputPath ./en-US
```
