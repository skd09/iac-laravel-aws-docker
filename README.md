# Laravel AWS DevOps

**Production-ready Infrastructure as Code for deploying multiple Laravel applications on AWS using Terraform, Ansible, Docker, and CodeDeploy.**

<p align="center">
  <a href="https://www.terraform.io/"><img src="https://img.shields.io/badge/Terraform-1.6%2B-7B42BC?logo=terraform" alt="Terraform"></a>
  <a href="https://www.ansible.com/"><img src="https://img.shields.io/badge/Ansible-2.9%2B-EE0000?logo=ansible" alt="Ansible"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Docker-24%2B-2496ED?logo=docker" alt="Docker"></a>
  <a href="https://aws.amazon.com/"><img src="https://img.shields.io/badge/AWS-EC2%20%7C%20RDS%20%7C%20S3-FF9900?logo=amazonaws" alt="AWS"></a>
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

---

## What Is This?

A complete DevOps toolkit for teams running **multiple Laravel apps on a single EC2 instance** with Docker containers. Born from production experience managing 5+ Laravel services across dev/staging environments.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Developer   │────▶│  Bitbucket   │────▶│     AWS      │────▶│     EC2      │
│  git push    │     │  Pipeline    │     │  CodeDeploy  │     │   Docker     │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                                         │
                            ▼                                         ▼
                     ┌──────────────┐                          ┌──────────────┐
                     │      S3      │                          │  N Laravel   │
                     │   Artifacts  │                          │  Apps in     │
                     └──────────────┘                          │  Docker      │
                                                               │  Containers  │
                                                               └──────────────┘
```

### Key Features

- **Terraform modules** for VPC, EC2, RDS, S3, ElastiCache, Security Groups, CloudWatch Monitoring, and Backups
- **Ansible roles** for Docker, Apache reverse proxy, PHP-FPM, CodeDeploy agent, and SSM secret management
- **Bitbucket Pipelines** templates (single-app and multi-instance) with OIDC authentication
- **Zero-downtime deployments** via AWS CodeDeploy with automatic rollback
- **Multi-app support** — run multiple Laravel apps (different PHP versions) on one EC2 via Docker
- **Secrets management** via AWS SSM Parameter Store (encrypted `.env` files)
- **Environment isolation** — separate DEV and STAG with different VPCs, configs, and feature flags
- **Helper scripts** for deployment, rollback, status checking, and SSM management

---

## Prerequisites

| Tool | Version | Install (macOS) |
|------|---------|-----------------|
| [Terraform](https://www.terraform.io/downloads) | >= 1.6 | `brew install terraform` |
| [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) | >= 2.9 | `brew install ansible` |
| [AWS CLI](https://aws.amazon.com/cli/) | >= 2.0 | `brew install awscli` |
| [jq](https://jqlang.github.io/jq/) | any | `brew install jq` |

---

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/yourorg/laravel-aws-devops.git
cd laravel-aws-devops
chmod +x scripts/*.sh

# Copy templates
cp ansible/group_vars/all_project.yml.example ansible/group_vars/all_project.yml
cp ansible/group_vars/dev_vault.yml.example ansible/group_vars/dev_vault.yml
cp ansible/inventories/dev.ini.example ansible/inventories/dev.ini
cp terraform/environments/dev/terraform.auto.tfvars.example terraform/environments/dev/terraform.auto.tfvars
```

### 2. Customize `ansible/group_vars/all.yml`

Define your apps — each with a name, repo URL, PHP version, ports, and branches:

```yaml
apps:
  - name: api
    repo: "{{ vault_repo_api }}"
    php_version: "8.3"
    laravel_version: 11
    instances:
      - id: api
        subdomain: "api"
        port: 8001
        db_name: "api"
        branches:
          dev: "dev"
          stag: "main"
```

### 3. Terraform — Create Infrastructure

```bash
cd terraform/environments/dev
export TF_VAR_ssh_allowed_cidrs='["YOUR_IP/32"]'
terraform init && terraform plan && terraform apply
terraform output ec2_public_ip
```

### 4. Ansible — Configure Server

```bash
# Update ansible/inventories/dev.ini with EC2 IP
# Update ansible/group_vars/all_project.yml with your project details
# Update ansible/group_vars/dev_vault.yml with secrets
./scripts/deploy.sh dev
```

### 5. SSM — Configure App Secrets

```bash
./scripts/setup-ssm.sh dev          # Interactive setup for all apps
./scripts/setup-ssm.sh dev api      # Single app
./scripts/setup-ssm.sh dev --list   # List existing params
```

### 6. Deploy via Git Push

```bash
git push origin dev    # → DEV environment
git push origin stag   # → STAG environment
```

---

## Project Structure

```
laravel-aws-devops/
├── ansible/                        # Server configuration
│   ├── inventories/               # Server IPs per environment
│   ├── group_vars/                # Environment variables & secrets
│   ├── playbooks/                 # Ansible playbooks
│   └── roles/                     # Reusable roles
│       ├── common/                # System packages
│       ├── docker/                # Docker + PHP base images
│       ├── apache/                # Apache reverse proxy
│       ├── php/                   # PHP-FPM (non-Docker fallback)
│       ├── codedeploy-agent/      # AWS CodeDeploy agent
│       ├── deploy/                # App directories + lifecycle scripts
│       └── ssm/                   # SSM parameter fetch
│
├── terraform/                     # AWS infrastructure as code
│   ├── backend-setup/             # One-time S3/DynamoDB backend
│   ├── environments/
│   │   ├── dev/                   # DEV-specific config
│   │   └── stag/                  # STAG-specific config
│   └── modules/                   # Reusable Terraform modules
│       ├── vpc/                   # VPC, subnets, routing
│       ├── ec2/                   # EC2 instance + EIP
│       ├── rds/                   # MySQL RDS
│       ├── s3/                    # S3 buckets with lifecycle
│       ├── security-groups/       # EC2, RDS, Redis SGs
│       ├── elasticache/           # Redis cluster
│       ├── monitoring/            # CloudWatch alarms + SNS
│       ├── backup/                # AWS Backup vault + plan
│       └── secrets/               # Secrets Manager
│
├── bitbucket-pipelines/           # CI/CD pipeline templates
│   ├── single-app-template.yml    # One repo → one app
│   ├── multi-instance-template.yml # One repo → multiple app instances
│   └── bitbucket-pipelines.yml    # Generic pipeline template
│
├── codedeploy/                    # Files to copy into Laravel repos
│   ├── appspec.yml                # CodeDeploy hook definitions
│   └── scripts/wrapper.sh         # Lifecycle event router
│
└── scripts/                       # Helper scripts
    ├── deploy.sh                  # Main Ansible runner
    ├── setup-ssm.sh               # SSM parameter CRUD
    ├── check-status.sh            # Health check all apps
    ├── rollback.sh                # Rollback via CodeDeploy
    └── validate-terraform.sh      # Validate all TF configs
```

---

## How Deployments Work

1. **Developer pushes** to `dev` or `stag` branch
2. **Bitbucket Pipeline** zips the code, uploads to S3, triggers CodeDeploy
3. **CodeDeploy** runs lifecycle hooks on EC2:
   - `BeforeInstall` — stops existing container, cleans up
   - `AfterInstall` — copies code, fetches `.env` from SSM, generates Dockerfile
   - `ApplicationStart` — builds & starts Docker container, runs migrations
   - `ValidateService` — health check with retries
4. **Auto-rollback** on failure

---

## Customization Guide

### Adding a New App

1. Add the app definition to `ansible/group_vars/all.yml` under `apps:`
2. Add the app name to `codedeploy_apps` in your Terraform `tfvars`
3. Run `./scripts/deploy.sh <env>` to create directories and Apache vhosts
4. Create SSM parameters: `./scripts/setup-ssm.sh <env> <app-name>`
5. Add `appspec.yml` and `scripts/wrapper.sh` to the Laravel repo
6. Push to trigger deployment

### Adapting for GitHub Actions

Replace Bitbucket Pipelines with GitHub Actions by uploading to S3 and triggering CodeDeploy. The server-side scripts (`/opt/scripts/codedeploy/`) work identically regardless of CI provider.

### Using Different CI/CD

The deployment scripts on the EC2 are CI-agnostic. Any system that can:
1. Zip your Laravel code
2. Upload to the S3 artifacts bucket
3. Call `aws deploy create-deployment`

...will work with this setup.

---

## Scripts Reference

| Script | Description | Usage |
|--------|-------------|-------|
| `deploy.sh` | Run Ansible playbook | `./scripts/deploy.sh dev` |
| `setup-ssm.sh` | Manage SSM parameters | `./scripts/setup-ssm.sh dev --list` |
| `check-status.sh` | Check app health | `./scripts/check-status.sh dev` |
| `rollback.sh` | Rollback deployments | `./scripts/rollback.sh dev api 2` |
| `validate-terraform.sh` | Validate all TF | `./scripts/validate-terraform.sh` |

---

## Configuration Files

### Files You Must Create (from `.example` templates)

| File | Template | Contains |
|------|----------|----------|
| `ansible/inventories/dev.ini` | `dev.ini.example` | EC2 IP, SSH key path |
| `ansible/group_vars/all_project.yml` | `all_project.yml.example` | Project name, repos, AWS account |
| `ansible/group_vars/dev_vault.yml` | `dev_vault.yml.example` | DB passwords, endpoints |
| `terraform/environments/dev/terraform.auto.tfvars` | `terraform.auto.tfvars.example` | Terraform variable values |

### Environment Variables for Terraform

```bash
export TF_VAR_project="myproject"
export TF_VAR_aws_region="us-east-1"
export TF_VAR_existing_rds_endpoint="your-rds.rds.amazonaws.com"
export TF_VAR_existing_rds_password="your-password"
export TF_VAR_ssh_allowed_cidrs='["YOUR_IP/32"]'
```

---

## Security

- **Secrets** stored in AWS SSM Parameter Store (KMS encrypted)
- **SSH** restricted to whitelisted IPs via security groups
- **No secrets in Git** — vault files, inventory, and tfvars are all gitignored
- **OIDC authentication** for Bitbucket Pipelines (no long-lived AWS credentials)
- **Auto-rollback** on failed deployments
- **IMDSv2 required** on EC2 instances

See [SECURITY.md](SECURITY.md) for full security documentation.

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

## Additional Documentation

| Document | Description |
|----------|-------------|
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Step-by-step initial deployment |
| [RUNBOOK.md](RUNBOOK.md) | Day-to-day operations guide |
| [SECURITY.md](SECURITY.md) | Security practices & policies |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
