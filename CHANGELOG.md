# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-02-11

### Added

- Initial open-source release
- Terraform modules: VPC, EC2, RDS, S3, Security Groups, ElastiCache, Monitoring, Backup, Secrets
- Ansible roles: common, docker, php, apache, codedeploy-agent, deploy, ssm
- Bitbucket Pipelines templates (single-app and multi-instance)
- CodeDeploy lifecycle scripts with auto-rollback
- Helper scripts: deploy, setup-ssm, check-status, rollback, validate-terraform
- Multi-app Docker support with PHP 8.0–8.3
- AWS SSM Parameter Store integration for secrets
- DEV and STAG environment configurations
- Comprehensive documentation: README, DEPLOYMENT_GUIDE, RUNBOOK, SECURITY
