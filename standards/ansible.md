# Ansible Development Standards

This document outlines the standards and best practices for Ansible playbook and role development in this organization.

## Project Structure

```
ProjectName/
├── playbooks/         # Main Ansible playbooks
├── roles/            # Custom Ansible roles
├── inventories/      # Inventory files (hosts, groups)
├── group_vars/       # Group-specific variables
├── host_vars/        # Host-specific variables
├── files/            # Static files to copy
├── templates/        # Jinja2 templates
├── tests/            # Molecule tests
├── docs/             # Documentation
└── README.md         # Project documentation
```

## Code Standards

### 1. Playbook Documentation
- **ALWAYS** include detailed comments at the top of every playbook
- Include: Purpose, Author, Required variables, Example usage, Dependencies
- Use YAML comments with `#` for inline documentation
- Document complex tasks and variables

### 2. YAML Formatting
- Use 2-space indentation consistently
- Use hyphens for list items with proper alignment
- Quote strings that contain special characters
- Use multi-line YAML for complex values
- Keep lines under 120 characters

### 3. Variable Management
- Use descriptive variable names with underscores: `web_server_port`
- Group related variables in dictionaries
- Define defaults in `defaults/main.yml`
- Use `group_vars` and `host_vars` appropriately
- Never hardcode sensitive data - use Ansible Vault

### 4. Task Organization
- Use meaningful task names with action descriptions
- Group related tasks using `block` constructs
- Use tags for selective task execution
- Include appropriate `when` conditions
- Use handlers for service restarts and notifications

### 5. Role Structure
- Follow Ansible Galaxy role structure
- Keep roles focused on single responsibility
- Use `meta/main.yml` for role dependencies
- Include role documentation in `README.md`
- Version roles using semantic versioning

### 6. Error Handling
- Use `failed_when` for custom failure conditions
- Implement `rescue` blocks for error recovery
- Use `ignore_errors` sparingly and document why
- Include meaningful error messages
- Test failure scenarios

### 7. Security Best Practices
- Use Ansible Vault for sensitive data
- Implement proper file permissions (mode, owner, group)
- Validate user input and file paths
- Use least privilege principle
- Never log sensitive information

### 8. Idempotency
- Ensure all tasks are idempotent
- Use appropriate modules (avoid shell/command when possible)
- Test multiple runs produce same results
- Use `changed_when` to control change reporting
- Implement proper check mode support

### 9. Performance Guidelines
- Use `serial` to control parallel execution
- Implement `strategy: free` when appropriate
- Use `async` for long-running tasks
- Minimize fact gathering with `gather_facts: false` when not needed
- Use `delegate_to` and `run_once` strategically

### 10. Testing Requirements
- Write Molecule tests for all roles
- Test on multiple platforms and versions
- Include linting tests (yamllint, ansible-lint)
- Test both success and failure scenarios
- Validate idempotency

## Required Tools and Modules

### Development Environment
- Ansible 4.0+ (ansible-core 2.11+)
- Python 3.8+
- Molecule for testing
- yamllint and ansible-lint for code quality

### Code Quality
- Run `ansible-lint` before committing
- Use `yamllint` for YAML formatting
- Address all Error and Warning level issues
- Use `.ansible-lint` configuration file

### Version Control
- Use semantic versioning (SemVer) for roles
- Write descriptive commit messages
- Create feature branches for new development
- Use pull requests for code review

## Template Usage

1. Copy the template structure
2. Rename files and directories appropriately
3. Update README.md with project-specific information
4. Follow the coding standards outlined above
5. Write Molecule tests for all roles
6. Run linting and tests before committing

## Enforcement

- All code must pass ansible-lint with no errors
- All roles must have proper documentation
- Code reviews are mandatory for all changes
- Automated testing must pass before merging

## Example Commands

### Running Playbooks
```bash
ansible-playbook -i inventories/production playbooks/site.yml --check
ansible-playbook -i inventories/production playbooks/site.yml --limit webservers
```

### Running Tests
```bash
molecule test
molecule test --all
```

### Code Analysis
```bash
ansible-lint playbooks/ roles/
yamllint .
```

### Managing Secrets
```bash
ansible-vault create group_vars/production/vault.yml
ansible-vault edit group_vars/production/vault.yml
```
