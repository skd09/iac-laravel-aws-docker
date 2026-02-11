# Contributing to Laravel AWS DevOps

Thank you for your interest in contributing! This project aims to provide a production-ready DevOps toolkit for Laravel teams deploying on AWS.

## How to Contribute

### Reporting Issues

- Use the [GitHub Issues](https://github.com/yourorg/laravel-aws-devops/issues) tab
- Include your environment details (OS, Terraform version, Ansible version)
- Provide steps to reproduce the issue
- Include relevant log output

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Make your changes
4. Test your changes (see Testing below)
5. Commit with a clear message: `git commit -m "Add support for PostgreSQL RDS"`
6. Push and open a Pull Request

### What We're Looking For

- **New Terraform modules** (e.g., ECS, Lambda, CloudFront)
- **GitHub Actions templates** as an alternative to Bitbucket Pipelines
- **Additional PHP versions** in Docker templates
- **Nginx support** as an alternative to Apache
- **Bug fixes** and documentation improvements
- **Tests** for Ansible roles and Terraform modules

## Code Guidelines

### Terraform

- Use `terraform fmt` before committing
- Run `terraform validate` on all environments
- Add descriptions to all variables and outputs
- Use modules for reusable components

### Ansible

- Follow [Ansible best practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- Use `ansible-lint` before committing
- Keep roles focused and single-purpose
- Use templates (`.j2`) over hardcoded values

### Shell Scripts

- Use `set -e` for error handling
- Include usage comments at the top
- Support `--help` flag
- Use colored output for clarity

### Documentation

- Update README.md if adding new features
- Add examples for new configuration options
- Keep DEPLOYMENT_GUIDE.md and RUNBOOK.md in sync

## Testing

### Terraform

```bash
./scripts/validate-terraform.sh
```

### Ansible (syntax check)

```bash
cd ansible
ansible-playbook --syntax-check -i inventories/dev.ini.example playbooks/full-setup.yml
```

### Shell Scripts (lint)

```bash
shellcheck scripts/*.sh
```

## Security

- Never commit secrets, credentials, or real IP addresses
- Use `.example` templates for any file containing sensitive data
- Report security vulnerabilities privately (see SECURITY.md)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
