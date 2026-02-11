# Security Documentation


<p align="center">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Guide-Security-red" alt="Security Guide">
  <img src="https://img.shields.io/badge/Classification-Public-green" alt="Classification: Public">
</p>

---

## Getting Started

This document outlines security practices, policies, and procedures for MyProject infrastructure. All team members must follow these guidelines.

---

## Security Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY LAYERS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│   │ Cloudflare  │    │   AWS WAF   │    │  Security   │                     │
│   │    DDoS     │───▶│  (if used)  │───▶│   Groups    │                     │
│   │ Protection  │    │             │    │             │                     │
│   └─────────────┘    └─────────────┘    └─────────────┘                     │
│                                               │                              │
│                                               ▼                              │
│                      ┌─────────────────────────────────────┐                │
│                      │              EC2                     │                │
│                      │  ┌─────────────────────────────┐    │                │
│                      │  │      Docker Containers      │    │                │
│                      │  │  (Isolated Applications)    │    │                │
│                      │  └─────────────────────────────┘    │                │
│                      │                │                     │                │
│                      │                ▼                     │                │
│                      │  ┌─────────────────────────────┐    │                │
│                      │  │    SSM Parameter Store      │    │                │
│                      │  │   (Encrypted Secrets)       │    │                │
│                      │  └─────────────────────────────┘    │                │
│                      └─────────────────────────────────────┘                │
│                                               │                              │
│                                               ▼                              │
│                      ┌─────────────────────────────────────┐                │
│                      │              RDS                     │                │
│                      │  (Encrypted at Rest & Transit)      │                │
│                      └─────────────────────────────────────┘                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Access Control

### Principle of Least Privilege

All access follows the principle of least privilege:
- Users only get permissions required for their role
- Service accounts have minimal necessary permissions
- Access is reviewed quarterly

### SSH Access

| Rule | Requirement |
|------|-------------|
| Key-based auth only | Password authentication disabled |
| IP whitelisting | Only allowed IPs can connect |
| Key rotation | Every 90 days |
| No root SSH | Direct root login disabled |

**Allowed SSH IPs are configured in:**
- Terraform: `ssh_allowed_cidrs` variable
- Security Group: Inbound rule on port 22

### AWS IAM

| Role | Purpose | Permissions |
|------|---------|-------------|
| EC2 Instance Role | App server | SSM read, S3 read/write, CloudWatch |
| CodeDeploy Role | Deployments | EC2 tags, S3 read |
| Bitbucket OIDC Role | CI/CD | S3 write, CodeDeploy create |

---

## Secrets Management

### What is Stored Where

| Secret Type | Storage | Encryption |
|-------------|---------|------------|
| Database passwords | AWS SSM Parameter Store | KMS encrypted |
| API keys | AWS SSM Parameter Store | KMS encrypted |
| SSH keys | Local `~/.ssh/` | File permissions 400 |
| Laravel APP_KEY | AWS SSM Parameter Store | KMS encrypted |
| AWS credentials | Local `~/.aws/` or env vars | IAM policies |

### Never Commit Secrets

The following files are gitignored and must **NEVER** be committed:

```gitignore
# SSH Keys
*.pem
*.key
terraform/environments/*/keys/

# Ansible Secrets
ansible/group_vars/*_vault.yml
ansible/group_vars/all_project.yml
ansible/inventories/*.ini

# Terraform Secrets
terraform/environments/*/secrets.tfvars
terraform/environments/*/*.tfstate

# Environment Files
.env
.envrc
```

### SSM Parameter Paths

Secrets are stored in AWS SSM Parameter Store:

```
/myproject/{env}/{app}/.env
```

All parameters use `SecureString` type with AWS-managed KMS encryption.

---

## Network Security

### Security Groups

| Security Group | Inbound Rules |
|----------------|---------------|
| EC2 | SSH (22) from allowed IPs, HTTP (80) from Cloudflare, HTTPS (443) from Cloudflare, App ports (8001-8007) from localhost |
| RDS | MySQL (3306) from EC2 security group only |
| ElastiCache | Redis (6379) from EC2 security group only |

### Cloudflare

| Setting | Value |
|---------|-------|
| SSL Mode | Full |
| Always Use HTTPS | Enabled |
| Minimum TLS Version | 1.2 |
| Automatic HTTPS Rewrites | Enabled |

### VPC

| Component | Configuration |
|-----------|---------------|
| VPC CIDR | 10.10.0.0/16 (DEV), 10.20.0.0/16 (STAG) |
| Public Subnets | EC2 instances |
| Private Subnets | RDS, ElastiCache |
| NAT Gateway | For private subnet internet access |

---

## Data Protection

### Encryption at Rest

| Resource | Encryption |
|----------|------------|
| RDS | AWS-managed encryption enabled |
| S3 | AES-256 server-side encryption |
| EBS Volumes | AWS-managed encryption enabled |
| SSM Parameters | KMS encryption (SecureString) |

### Encryption in Transit

| Connection | Encryption |
|------------|------------|
| User → Cloudflare | TLS 1.2+ |
| Cloudflare → EC2 | HTTPS (Full mode) |
| EC2 → RDS | TLS required |
| EC2 → S3 | HTTPS |

### Backup & Recovery

| Resource | Backup | Retention |
|----------|--------|-----------|
| RDS | Automated daily | 7 days |
| S3 | Versioning enabled | 30 days |
| EC2 | AMI snapshots | Manual |

---

## Application Security

### Laravel Security Settings

Production `.env` must include:

```env
APP_DEBUG=false
APP_ENV=production
SESSION_SECURE_COOKIE=true
SESSION_HTTP_ONLY=true
```

### CORS Configuration

Configure in Laravel `config/cors.php`:

```php
'allowed_origins' => [
    'https://app-api-dev.example.com',
    'https://app-dashboard-dev.example.com',
    // ... other allowed origins
],
```

### Rate Limiting

Laravel rate limiting in `app/Http/Kernel.php`:

```php
'api' => [
    'throttle:60,1',
    // ...
],
```

---

## CI/CD Security

### Bitbucket Pipeline Security

| Practice | Implementation |
|----------|----------------|
| OIDC Authentication | No long-lived AWS credentials |
| Branch Protection | Only `dev`/`stag`/`main` trigger deploys |
| Artifact Signing | Zip files verified by CodeDeploy |

### CodeDeploy Security

| Practice | Implementation |
|----------|----------------|
| S3 Access | Bucket policy restricts access |
| IAM Roles | Minimal permissions for deployment |
| Auto-Rollback | Enabled on deployment failure |

---

## Incident Response

### Security Incident Types

| Severity | Example | Response Time |
|----------|---------|---------------|
| Critical | Data breach, unauthorized access | Immediate |
| High | Suspected intrusion, DDoS | 1 hour |
| Medium | Failed login attempts spike | 4 hours |
| Low | Security scan findings | 24 hours |

### Response Steps

1. **Identify**: Determine scope and impact
2. **Contain**: Isolate affected systems
3. **Eradicate**: Remove threat
4. **Recover**: Restore services
5. **Document**: Record incident details
6. **Review**: Post-incident analysis

### Emergency Contacts

| Role | Contact |
|------|---------|
| DevOps Lead | [Contact Info] |
| Security Team | [Contact Info] |
| AWS Support | AWS Console Support |

---

## Security Checklist

### Before Deployment

- [ ] No secrets in code
- [ ] APP_DEBUG=false in production
- [ ] SSH keys not committed
- [ ] Security groups reviewed
- [ ] IAM roles have minimal permissions

### After Deployment

- [ ] Health checks passing
- [ ] SSL working correctly
- [ ] Logs not exposing secrets
- [ ] Error pages don't leak info

### Quarterly Review

- [ ] Rotate SSH keys
- [ ] Review IAM permissions
- [ ] Audit security groups
- [ ] Check for unused resources
- [ ] Update dependencies
- [ ] Review access logs

---

## Compliance

### Data Residency

All data is stored in **ca-central-1** (Canada) region to comply with Canadian data residency requirements.

### Logging & Audit

| Log Type | Retention | Storage |
|----------|-----------|---------|
| CloudWatch Logs | 30 days | AWS CloudWatch |
| Apache Access Logs | 7 days | EC2 local |
| Laravel Logs | 7 days | EC2 local |
| CodeDeploy Logs | 30 days | EC2 local |

### Access Logging

AWS CloudTrail is enabled to log all API calls for audit purposes.

---

## Security Best Practices

### Do's ✅

- Use SSM Parameter Store for secrets
- Use environment variables for sensitive config
- Enable MFA for AWS Console access
- Use security groups to restrict access
- Keep dependencies updated
- Monitor CloudWatch for anomalies
- Use HTTPS everywhere
- Encrypt data at rest and in transit

### Don'ts ❌

- Never commit secrets to Git
- Never use root AWS credentials
- Never disable SSL/TLS
- Never expose debug info in production
- Never use default passwords
- Never share SSH keys
- Never open ports to 0.0.0.0/0 unnecessarily
- Never store passwords in plain text

---

## Vulnerability Management

### Dependency Updates

```bash
# Check Laravel dependencies
composer outdated

# Update dependencies
composer update
```

### Security Scanning

Regular scans should be performed:

| Tool | Frequency | Purpose |
|------|-----------|---------|
| `composer audit` | Weekly | PHP dependency vulnerabilities |
| AWS Inspector | Monthly | EC2 vulnerabilities |
| Cloudflare WAF | Continuous | Web application firewall |

### Reporting Vulnerabilities

If you discover a security vulnerability:

1. Do not disclose publicly
2. Contact DevOps/Security team immediately
3. Document the finding
4. Work on remediation

---

## Useful Commands

### Check Open Ports

```bash
sudo netstat -tlnp
```

### Check Active SSH Sessions

```bash
who
```

### Check Failed Login Attempts

```bash
sudo grep "Failed password" /var/log/auth.log | tail -20
```

### Check Security Group Rules

```bash
aws ec2 describe-security-groups \
  --group-ids sg-XXXXXXXXX \
  --region ca-central-1 \
  --query 'SecurityGroups[*].IpPermissions'
```

### Check IAM Role Permissions

```bash
aws iam list-attached-role-policies --role-name myproject-dev-ec2-role
```

---

## Meta

Open source project. Contributions welcome!

Licensed under MIT. See LICENSE.

**Classification:** Internal Use Only

---

## References

* [README.md](README.md) - Project overview
* [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Initial setup guide
* [RUNBOOK.md](RUNBOOK.md) - Operations guide
* [AWS Security Best Practices](https://aws.amazon.com/security/)
* [OWASP Top 10](https://owasp.org/www-project-top-ten/)
