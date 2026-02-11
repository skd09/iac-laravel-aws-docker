# Deployment Guide


<p align="center">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Guide-Deployment-blue" alt="Deployment Guide">
  <img src="https://img.shields.io/badge/Time-45%20mins-green" alt="Estimated Time: 45 mins">
  <img src="https://img.shields.io/badge/Difficulty-Intermediate-yellow" alt="Difficulty: Intermediate">
</p>

---

## Getting Started

This guide walks you through deploying MyProject infrastructure from scratch. Follow each phase in order.

### What You'll Set Up

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INFRASTRUCTURE OVERVIEW                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│   │   VPC       │    │    EC2      │    │    RDS      │                     │
│   │  10.x.0.0   │───▶│  t3.medium  │───▶│   MySQL     │                     │
│   └─────────────┘    └─────────────┘    └─────────────┘                     │
│                             │                                                │
│                             ▼                                                │
│                      ┌─────────────┐                                        │
│                      │   Docker    │                                        │
│                      │ ┌─────────┐ │                                        │
│                      │ │ app-api    │ │  Port 8001                             │
│                      │ │ app-worker │ │  Port 8002                             │
│                      │ │ app-web │ │  Port 8003                             │
│                      │ │ buildstr│ │  Port 8005                             │
│                      │ │ app-dashboard  │ │  Port 8007                             │
│                      │ └─────────┘ │                                        │
│                      └─────────────┘                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before starting, ensure you have:

| Requirement | Version | Check Command |
|-------------|---------|---------------|
| Terraform | >= 1.0 | `terraform version` |
| Ansible | >= 2.9 | `ansible --version` |
| AWS CLI | >= 2.0 | `aws --version` |
| jq | any | `jq --version` |

### Install Tools (macOS)

```bash
brew install terraform ansible awscli jq
```

### Configure AWS

```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: ca-central-1
# Output format: json

# Verify
aws sts get-caller-identity
```

---

## Phase 1: Initial Setup

**Estimated Time:** 5 minutes

### 1.1 Clone Repository

```bash
git clone git@bitbucket.org:yourorg/laravel-aws-devops.git
cd myproject-devops
```

### 1.2 Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

### 1.3 Get Your IP Address

```bash
curl -s https://checkip.amazonaws.com
# Save this - you'll need it for SSH access
```

### 1.4 Copy Configuration Templates

```bash
# Ansible templates
cp ansible/group_vars/all_project.yml.example ansible/group_vars/all_project.yml
cp ansible/group_vars/dev_vault.yml.example ansible/group_vars/dev_vault.yml
cp ansible/inventories/dev.ini.example ansible/inventories/dev.ini

# For STAG (if needed)
cp ansible/group_vars/stag_vault.yml.example ansible/group_vars/stag_vault.yml
cp ansible/inventories/stag.ini.example ansible/inventories/stag.ini
```

---

## Phase 2: Terraform Infrastructure

**Estimated Time:** 15 minutes

### 2.1 Navigate to Environment

```bash
cd terraform/environments/dev
```

### 2.2 Set Environment Variables

```bash
# Required variables
export TF_VAR_project="myproject"
export TF_VAR_aws_region="ca-central-1"
export TF_VAR_ops_name="devops"

# SSH access (use your IP from step 1.3)
export TF_VAR_ssh_allowed_cidrs='["YOUR_IP/32"]'

# If using existing RDS
export TF_VAR_existing_rds_endpoint="your-rds.ca-central-1.rds.amazonaws.com"
export TF_VAR_existing_rds_username="myproject"
export TF_VAR_existing_rds_password="your-secure-password"

# If using existing VPC
export TF_VAR_existing_vpc_id="vpc-xxxxxxxxx"
export TF_VAR_existing_public_subnet_ids='["subnet-xxx", "subnet-yyy"]'
export TF_VAR_existing_data_subnet_ids='["subnet-aaa", "subnet-bbb"]'
```

### 2.3 Review Configuration

Check `terraform.auto.tfvars`:

```hcl
# Key settings to verify
environment        = "dev"
create_vpc         = false    # true if creating new VPC
create_rds         = false    # true if creating new RDS
create_s3          = true
create_codedeploy  = true
create_ssh_key     = true
ec2_instance_type  = "t3.medium"
```

### 2.4 Initialize and Apply

```bash
# Initialize
terraform init

# Preview changes
terraform plan

# Apply (type 'yes' when prompted)
terraform apply

# Save the EC2 IP
terraform output ec2_public_ip
```

### 2.5 Copy SSH Key

```bash
# Key is created in keys/ directory
cp keys/myproject-dev-key.pem ~/.ssh/
chmod 400 ~/.ssh/myproject-dev-key.pem

# Test SSH
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP "echo 'SSH OK'"
```

---

## Phase 3: Ansible Configuration

**Estimated Time:** 10 minutes

### 3.1 Update Inventory

Edit `ansible/inventories/dev.ini`:

```ini
[dev]
dev-server ansible_host=YOUR_EC2_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/myproject-dev-key.pem

[dev:vars]
env=dev
ansible_python_interpreter=/usr/bin/python3
```

### 3.2 Update Project Variables

Edit `ansible/group_vars/all_project.yml`:

```yaml
---
# Project Identification
project_name: "myproject"
ops_name: "devops"
aws_region: "ca-central-1"
base_domain: "example.com"

# Git Repositories
vault_repo_app_api: "git@bitbucket.org:yourorg/app-api.git"
vault_repo_app_web: "git@bitbucket.org:yourorg/app-web.git"
vault_repo_app-admin: "git@bitbucket.org:yourorg/app_app-admin_server.git"
vault_repo_app_dashboard: "git@bitbucket.org:yourorg/app-dashboard.git"

# AWS
aws_account_id: "YOUR_AWS_ACCOUNT_ID"
vault_ssl_email: "admin@example.com"

# CodeDeploy
codedeploy_agent_url: "https://aws-codedeploy-ca-central-1.s3.ca-central-1.amazonaws.com/latest/install"
```

### 3.3 Update Vault Secrets

Edit `ansible/group_vars/dev_vault.yml`:

```yaml
---
# Database
vault_db_host: "your-rds.ca-central-1.rds.amazonaws.com"
vault_db_password: "your-secure-password"

# Redis
vault_redis_host: "127.0.0.1"
vault_redis_password: ""
```

### 3.4 Run Ansible Playbook

```bash
cd ../..  # Back to project root

# Run full setup
./scripts/deploy.sh dev

# Or with verbose output
./scripts/deploy.sh dev --verbose
```

### 3.5 Verify Installation

```bash
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP

# Check Docker
docker ps

# Check Apache
sudo systemctl status apache2

# Check CodeDeploy agent
sudo service codedeploy-agent status

# Check directories
ls -la /var/www/
ls -la /opt/scripts/codedeploy/

exit
```

---

## Phase 4: SSM Parameters

**Estimated Time:** 10 minutes

### 4.1 Create Parameters for All Apps

```bash
# Interactive setup for all apps
./scripts/setup-ssm.sh dev
```

When prompted, enter values for each app:

```env
APP_NAME="app-api"
APP_ENV=dev
APP_KEY=base64:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
APP_DEBUG=true
APP_URL=https://app-api-dev.example.com

DB_CONNECTION=mysql
DB_HOST=your-rds.ca-central-1.rds.amazonaws.com
DB_PORT=3306
DB_DATABASE=app_api_dev
DB_USERNAME=myproject
DB_PASSWORD=your-secure-password

SESSION_DRIVER=file
CACHE_DRIVER=file
QUEUE_CONNECTION=sync

AWS_DEFAULT_REGION=ca-central-1
AWS_BUCKET=myproject-dev-app-api-uploads
```

### 4.2 Verify Parameters

```bash
./scripts/setup-ssm.sh dev --list
```

Expected output:
```
/myproject/dev/app-api/.env
/myproject/dev/app-worker/.env
/myproject/dev/app-web/.env
/myproject/dev/app-admin/.env
/myproject/dev/app-dashboard/.env
```

---

## Phase 5: Laravel Repository Setup

**Estimated Time:** 5 minutes per repo

### 5.1 Files to Add to Each Laravel Repo

Copy from devops repo:

| Source | Destination |
|--------|-------------|
| `codedeploy/appspec.yml` | Repo root |
| `codedeploy/scripts/wrapper.sh` | `scripts/wrapper.sh` |
| `bitbucket-pipelines/single-app-template.yml` | `bitbucket-pipelines.yml` |

### 5.2 Update wrapper.sh

Edit `scripts/wrapper.sh` and set `APP_NAME`:

```bash
# Change this line for each repo
APP_NAME="app-dashboard"   # Options: app-api, app-worker, app-web, app-admin, app-dashboard
```

### 5.3 Update bitbucket-pipelines.yml

Change `APP_NAME` in both DEV and STAG steps:

```yaml
- export APP_NAME="app-dashboard"   # Match your app
```

### 5.4 Create Health Check

Create `public/health.php`:

```php
<?php
http_response_code(200);
header('Content-Type: application/json');
echo json_encode([
    'status' => 'ok',
    'timestamp' => date('c'),
    'app' => 'app-dashboard'
]);
```

### 5.5 Commit and Push

```bash
git add appspec.yml scripts/ bitbucket-pipelines.yml public/health.php
git commit -m "Add deployment configuration"
git push origin dev
```

### 5.6 Repeat for Each App

| Repository | APP_NAME | Branch |
|------------|----------|--------|
| app-dashboard | `app-dashboard` | dev |
| myproject_server | `app-web` | dev |
| app_app-admin_server | `app-admin` | dev |
| app-api | `app-api` | dev |
| app-api | `app-worker` | feature/feature-branch |

---

## Phase 6: DNS Configuration

**Estimated Time:** 5 minutes

### 6.1 Add DNS Records in Cloudflare

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | app-api-dev | YOUR_EC2_IP | Proxied ✅ |
| A | app-worker-dev | YOUR_EC2_IP | Proxied ✅ |
| A | app-web-dev | YOUR_EC2_IP | Proxied ✅ |
| A | app-admin-dev | YOUR_EC2_IP | Proxied ✅ |
| A | app-dashboard-dev | YOUR_EC2_IP | Proxied ✅ |

### 6.2 SSL Settings

In Cloudflare SSL/TLS:
- Mode: **Full**

---

## Phase 7: Verification

### 7.1 Check Deployment Status

```bash
./scripts/check-status.sh dev
```

### 7.2 Test Each App

```bash
# Test health endpoints
curl -s https://app-api-dev.example.com/health.php | jq
curl -s https://app-dashboard-dev.example.com/health.php | jq

# Test direct ports (from EC2)
curl -s http://localhost:8001/health.php
curl -s http://localhost:8007/health.php
```

### 7.3 Check Containers

```bash
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP "docker ps"
```

Expected:
```
CONTAINER ID   IMAGE          STATUS         PORTS                    NAMES
abc123         app-api:latest    Up 2 hours     0.0.0.0:8001->80/tcp    app-api-dev-app
def456         app-dashboard:latest  Up 2 hours     0.0.0.0:8007->80/tcp    app-dashboard-dev-app
...
```

---

## Deploying STAG Environment

Repeat the same process with these changes:

| Setting | DEV | STAG |
|---------|-----|------|
| Environment | `dev` | `stag` |
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` |
| Branch | `dev` | `stag` / `main` |
| APP_DEBUG | `true` | `false` |
| APP_ENV | `local` | `staging` |

### Quick Commands for STAG

```bash
# 1. Terraform
cd terraform/environments/stag
export TF_VAR_project="myproject"
# ... set other variables
terraform init && terraform apply

# 2. Ansible
cp ansible/inventories/stag.ini.example ansible/inventories/stag.ini
# Edit with STAG EC2 IP
./scripts/deploy.sh stag

# 3. SSM
./scripts/setup-ssm.sh stag

# 4. Deploy via Bitbucket
git push origin stag
```

---

## Final Checklist

### Infrastructure
- [ ] Terraform applied successfully
- [ ] EC2 instance running
- [ ] SSH key saved to `~/.ssh/`
- [ ] Security group allows SSH (port 22)

### Server Configuration
- [ ] Ansible playbook completed
- [ ] Docker installed and running
- [ ] Apache configured as reverse proxy
- [ ] CodeDeploy agent running
- [ ] App directories created

### Application
- [ ] SSM parameters created for all 5 apps
- [ ] CodeDeploy files in all Laravel repos
- [ ] Bitbucket pipelines configured
- [ ] First deployment successful

### DNS
- [ ] DNS records pointing to EC2
- [ ] SSL working via Cloudflare

### Verification
- [ ] Health endpoints responding
- [ ] Database connections working
- [ ] All 5 apps accessible

---

## Common Issues

### Deployment Fails

```bash
# Check CodeDeploy logs
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP
cat /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log | tail -100
```

### Container Not Starting

```bash
docker logs app-api-dev-app
```

### .env Not Loading

```bash
# Check SSM parameter exists
aws ssm get-parameter --name "/myproject/dev/app-api/.env" --region ca-central-1

# Check .env on server
cat /var/www/app-api/.env
```

---

## Meta

Open source project. Contributions welcome!

Licensed under MIT. See LICENSE.

---

## References

* [README.md](README.md) - Project overview
* [RUNBOOK.md](RUNBOOK.md) - Day-to-day operations
* [SECURITY.md](SECURITY.md) - Security documentation
