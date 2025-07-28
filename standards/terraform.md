# Terraform Development Standards

This document outlines the standards and best practices for Terraform infrastructure-as-code development in this organization.

## Project Structure

```
ProjectName/
├── environments/     # Environment-specific configurations
│   ├── dev/         # Development environment
│   ├── staging/     # Staging environment
│   └── prod/        # Production environment
├── modules/         # Reusable Terraform modules
├── policies/        # Sentinel/OPA policies
├── scripts/         # Helper scripts and automation
├── tests/           # Terraform tests (terratest)
├── docs/            # Documentation
├── .terraform/      # Terraform working directory (git ignored)
└── README.md        # Project documentation
```

## Code Standards

### 1. File Organization and Naming
- Use descriptive file names: `main.tf`, `variables.tf`, `outputs.tf`
- Group related resources in logical files: `networking.tf`, `security.tf`
- Use consistent naming across environments
- Include `versions.tf` for provider version constraints
- Use `terraform.tf` for Terraform version requirements

### 2. Resource Naming Conventions
- Use consistent naming pattern: `{project}-{environment}-{resource-type}-{purpose}`
- Use lowercase with hyphens for resource names
- Use descriptive names that indicate purpose
- Avoid abbreviations unless widely understood
- Use prefixes for resource grouping

### 3. Variable Management
- **ALWAYS** define variables with descriptions, types, and defaults
- Use snake_case for variable names: `vpc_cidr_block`
- Group related variables together
- Use validation blocks for input validation
- Separate sensitive variables appropriately

### 4. Documentation Standards
- Include detailed comments for complex resources
- Document all variables with clear descriptions
- Include examples in variable descriptions
- Maintain up-to-date README.md files
- Document module usage and requirements

### 5. Module Development
- Keep modules focused on single responsibility
- Use semantic versioning for module releases
- Include comprehensive examples
- Provide clear input/output documentation
- Test modules independently

### 6. State Management
- Use remote state backends (S3, Terraform Cloud, etc.)
- Enable state locking to prevent conflicts
- Use separate state files per environment
- Never commit state files to version control
- Implement state backup strategies

### 7. Security Best Practices
- Never hardcode secrets or credentials
- Use Terraform data sources for sensitive information
- Implement least privilege access principles
- Enable encryption for sensitive resources
- Use secure communication protocols

### 8. Code Formatting and Style
- Use `terraform fmt` for consistent formatting
- Use 2-space indentation
- Align resource arguments for readability
- Use meaningful resource and data source names
- Keep line length reasonable (120 characters)

### 9. Resource Management
- Use data sources instead of hardcoded values when possible
- Implement proper resource dependencies
- Use `depends_on` explicitly when needed
- Tag all resources consistently
- Implement resource lifecycle management

### 10. Testing Requirements
- Write tests using Terratest or similar framework
- Test module functionality and edge cases
- Validate resource creation and configuration
- Test infrastructure changes in non-production first
- Include integration tests for complex setups

## Required Tools and Standards

### Development Environment
- Terraform 1.0+ (prefer latest stable version)
- terraform-docs for documentation generation
- tflint for additional linting
- terragrunt for DRY configurations (if applicable)

### Code Quality
- Run `terraform fmt` before committing
- Use `terraform validate` to check syntax
- Run `tflint` for additional checks
- Use pre-commit hooks for automation
- Address all validation errors and warnings

### Version Control
- Use semantic versioning for modules and major changes
- Write descriptive commit messages
- Create feature branches for new development
- Use pull requests for code review
- Tag stable releases

## Template Usage

1. Copy the template structure
2. Rename files and directories appropriately
3. Update README.md with project-specific information
4. Configure backend and provider requirements
5. Follow the coding standards outlined above
6. Write tests for infrastructure components
7. Run validation and formatting before committing

## Enforcement

- All code must pass terraform validate with no errors
- All modules must have proper documentation
- Code reviews are mandatory for all changes
- Infrastructure changes must be tested before production deployment

## Example Commands

### Basic Operations
```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

### Code Quality
```bash
terraform fmt -recursive
terraform validate
tflint --recursive
```

### Documentation
```bash
terraform-docs markdown table --output-file README.md .
```

### Testing
```bash
# Using Terratest
go test -v -timeout 30m
```

## Configuration Examples

### Provider Configuration
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}
```

### Variable Definition
```hcl
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR."
  }
}
```

### Output Definition
```hcl
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}
```

### Resource Tagging
```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-web-server"
      Role = "web-server"
    }
  )
}
```
