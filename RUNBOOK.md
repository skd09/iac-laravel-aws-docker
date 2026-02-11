# Operations Runbook


<p align="center">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Guide-Operations-orange" alt="Operations Runbook">
  <img src="https://img.shields.io/badge/Audience-DevOps%20%7C%20Developers-blue" alt="Audience: DevOps | Developers">
</p>

---

## Getting Started

This runbook covers day-to-day operations for managing MyProject infrastructure. Use this guide for routine tasks, troubleshooting, and emergency procedures.

---

## Quick Reference

### SSH Access

```bash
# DEV
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@DEV_EC2_IP

# STAG
ssh -i ~/.ssh/myproject-stag-key.pem ubuntu@STAG_EC2_IP
```

### App Ports

| App | Port | Container Name |
|-----|------|----------------|
| app-api | 8001 | `app-api-{env}-app` |
| app-worker | 8002 | `app-worker-{env}-app` |
| app-web | 8003 | `app-web-{env}-app` |
| app-admin | 8005 | `app-admin-{env}-app` |
| app-dashboard | 8007 | `app-dashboard-{env}-app` |

### Important Paths (on EC2)

| Path | Description |
|------|-------------|
| `/var/www/{app}` | Application code |
| `/var/www/{app}/.env` | Environment config |
| `/var/www/{app}/storage/logs` | Laravel logs |
| `/opt/scripts/codedeploy/` | Deployment scripts |
| `/opt/codedeploy-agent/deployment-root/deployment-logs/` | CodeDeploy logs |
| `/etc/apache2/sites-available/` | Apache vhosts |

---

## Daily Operations

### Check System Status

```bash
# Quick status check
./scripts/check-status.sh dev
./scripts/check-status.sh stag
```

### View Running Containers

```bash
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP "docker ps"
```

Expected output:
```
CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES
abc123         app-api:latest    Up 5 hours     0.0.0.0:8001->80/tcp  app-api-dev-app
def456         app-dashboard:latest  Up 5 hours     0.0.0.0:8007->80/tcp  app-dashboard-dev-app
```

### View Logs

```bash
# SSH to server first
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP

# Laravel logs
docker exec app-dashboard-dev-app tail -100 /var/www/html/storage/logs/laravel.log

# Docker container logs
docker logs --tail 100 app-dashboard-dev-app

# Apache logs
sudo tail -100 /var/log/apache2/app-dashboard-access.log
sudo tail -100 /var/log/apache2/app-dashboard-error.log

# CodeDeploy logs
tail -100 /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log
```

---

## Deployments

### Automatic Deployment (Git Push)

```bash
# Deploy to DEV
git push origin dev

# Deploy to STAG
git push origin stag
```

### Monitor Deployment

**Via AWS CLI:**

```bash
# List recent deployments
aws deploy list-deployments \
  --application-name myproject-dev-apps \
  --deployment-group-name myproject-dev-app-dashboard \
  --region ca-central-1

# Get deployment status
aws deploy get-deployment \
  --deployment-id d-XXXXXXXXX \
  --region ca-central-1 \
  --query 'deploymentInfo.status'
```

**Via EC2 Logs:**

```bash
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP \
  "tail -f /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log"
```

### Manual Deployment

```bash
# List available zip files
aws s3 ls s3://myproject-dev-codedeploy-artifacts/ | grep app-dashboard

# Deploy specific version
aws deploy create-deployment \
  --application-name myproject-dev-apps \
  --deployment-group-name myproject-dev-app-dashboard \
  --s3-location bucket=myproject-dev-codedeploy-artifacts,key=app-dashboard-abc123.zip,bundleType=zip \
  --region ca-central-1
```

---

## Rollbacks

### Using Rollback Script

```bash
# List available versions
./scripts/rollback.sh dev app-dashboard

# Output:
#  1. 2026-01-26 app-dashboard-abc123.zip  (current)
#  2. 2026-01-25 app-dashboard-def456.zip
#  3. 2026-01-24 app-dashboard-ghi789.zip

# Rollback to 2nd most recent
./scripts/rollback.sh dev app-dashboard 2

# Rollback to specific version
./scripts/rollback.sh dev app-dashboard app-dashboard-def456.zip
```

### Manual Rollback via AWS

```bash
# Get previous deployment revision
aws s3 ls s3://myproject-dev-codedeploy-artifacts/ | grep app-dashboard | sort | tail -5

# Deploy older version
aws deploy create-deployment \
  --application-name myproject-dev-apps \
  --deployment-group-name myproject-dev-app-dashboard \
  --s3-location bucket=myproject-dev-codedeploy-artifacts,key=app-dashboard-OLDER_COMMIT.zip,bundleType=zip \
  --region ca-central-1
```

### Auto-Rollback

CodeDeploy automatically rolls back on failure. Verify it's enabled:

```bash
aws deploy get-deployment-group \
  --application-name myproject-dev-apps \
  --deployment-group-name myproject-dev-app-dashboard \
  --region ca-central-1 \
  --query 'deploymentGroupInfo.autoRollbackConfiguration'
```

---

## Troubleshooting

### App Returns 500 Error

**Step 1: Check Laravel logs**

```bash
docker exec app-dashboard-dev-app cat /var/www/html/storage/logs/laravel.log | tail -50
```

**Step 2: Check .env is correct**

```bash
cat /var/www/app-dashboard/.env | grep -E "(APP_URL|DB_HOST|APP_DEBUG)"
```

**Step 3: Clear caches**

```bash
docker exec app-dashboard-dev-app php artisan config:clear
docker exec app-dashboard-dev-app php artisan cache:clear
docker exec app-dashboard-dev-app php artisan view:clear
docker exec app-dashboard-dev-app php artisan route:clear
```

**Step 4: Check permissions**

```bash
docker exec app-dashboard-dev-app chmod -R 775 /var/www/html/storage
docker exec app-dashboard-dev-app chmod -R 775 /var/www/html/bootstrap/cache
```

---

### Database Connection Error

**Step 1: Verify .env credentials**

```bash
grep DB_ /var/www/app-dashboard/.env
```

**Step 2: Test connection from EC2**

```bash
nc -zv RDS_ENDPOINT 3306
```

**Step 3: Check RDS security group**

Ensure EC2 security group is allowed inbound on port 3306.

**Step 4: Test from container**

```bash
docker exec -it app-dashboard-dev-app php artisan tinker
# >>> DB::connection()->getPdo();
```

---

### Docker Container Not Starting

**Step 1: Check logs**

```bash
docker logs app-dashboard-dev-app
```

**Step 2: Check port conflicts**

```bash
sudo netstat -tlnp | grep 8007
```

**Step 3: Rebuild container**

```bash
cd /var/www/app-dashboard
docker-compose -f docker-compose.server.yml down
docker-compose -f docker-compose.server.yml up -d --build
```

**Step 4: Check disk space**

```bash
df -h
docker system df
```

---

### CodeDeploy Fails

**Step 1: Check agent status**

```bash
sudo service codedeploy-agent status
```

**Step 2: Restart agent if needed**

```bash
sudo service codedeploy-agent restart
```

**Step 3: Check deployment logs**

```bash
cat /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log | tail -100
```

**Step 4: Verify EC2 tags**

```bash
aws ec2 describe-instances \
  --instance-ids i-XXXXXXXXX \
  --query 'Reservations[].Instances[].Tags' \
  --region ca-central-1
```

---

### Apache Shows Default Page

**Step 1: Check vhost is enabled**

```bash
ls -la /etc/apache2/sites-enabled/
```

**Step 2: Disable default site**

```bash
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
```

**Step 3: Verify ServerName**

```bash
cat /etc/apache2/sites-available/app-dashboard.conf | grep ServerName
```

---

### SSM Parameter Not Found

**Step 1: List existing parameters**

```bash
aws ssm get-parameters-by-path \
  --path "/myproject/dev/" \
  --recursive \
  --region ca-central-1 \
  --query 'Parameters[*].Name'
```

**Step 2: Create missing parameter**

```bash
./scripts/setup-ssm.sh dev app-dashboard
```

---

## Maintenance

### Update Server Packages

```bash
ssh -i ~/.ssh/myproject-dev-key.pem ubuntu@EC2_IP

sudo apt update
sudo apt upgrade -y

# Reboot if kernel was updated
sudo reboot
```

### Update Docker Images

```bash
# Rebuild all containers with latest base images
for app in app-api app-worker app-web app-admin app-dashboard; do
  cd /var/www/$app
  docker-compose -f docker-compose.server.yml down
  docker-compose -f docker-compose.server.yml build --no-cache
  docker-compose -f docker-compose.server.yml up -d
done
```

### Clean Up Docker

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Full cleanup (CAUTION)
docker system prune -a
```

### Update Ansible Configuration

```bash
# Re-run Ansible to apply changes
./scripts/deploy.sh dev
./scripts/deploy.sh stag
```

### Rotate Database Password

1. Update RDS password in AWS Console
2. Update SSM parameters:
   ```bash
   ./scripts/setup-ssm.sh dev app-dashboard  # Update DB_PASSWORD
   ```
3. Redeploy app to fetch new .env:
   ```bash
   ./scripts/rollback.sh dev app-dashboard 1  # Redeploy current version
   ```

---

## Emergency Procedures

### App Completely Down

**Step 1: Check container**

```bash
docker ps | grep app-dashboard
```

**Step 2: Start if stopped**

```bash
cd /var/www/app-dashboard
docker-compose -f docker-compose.server.yml up -d
```

**Step 3: Check Apache**

```bash
sudo systemctl status apache2
sudo systemctl start apache2
```

**Step 4: Rollback if needed**

```bash
./scripts/rollback.sh dev app-dashboard 2
```

---

### EC2 Instance Unreachable

**Step 1: Check instance in AWS Console**

**Step 2: Check security group allows SSH**

**Step 3: Stop/Start instance**

```bash
aws ec2 stop-instances --instance-ids i-XXXXXXXXX --region ca-central-1
# Wait 30 seconds
aws ec2 start-instances --instance-ids i-XXXXXXXXX --region ca-central-1
```

**Step 4: Check system logs**

```bash
aws ec2 get-console-output --instance-id i-XXXXXXXXX --region ca-central-1
```

---

### Database Unreachable

**Step 1: Check RDS status in AWS Console**

**Step 2: Check security group allows EC2**

**Step 3: Test from EC2**

```bash
nc -zv RDS_ENDPOINT 3306
```

**Step 4: Check RDS event logs in AWS Console**

---

### Restore from Backup (RDS)

```bash
# Point-in-time recovery
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myproject-dev-rds \
  --target-db-instance-identifier myproject-dev-rds-restored \
  --restore-time 2026-01-26T12:00:00Z \
  --region ca-central-1
```

---

## Monitoring Commands

### Check Disk Space

```bash
df -h
```

### Check Memory

```bash
free -m
```

### Check CPU

```bash
top -bn1 | head -20
```

### Check Docker Resource Usage

```bash
docker stats --no-stream
```

### Check Active Connections

```bash
netstat -an | grep ESTABLISHED | wc -l
```

---

## Useful Scripts

### Restart All Apps

```bash
#!/bin/bash
for app in app-api app-worker app-web app-admin app-dashboard; do
  echo "Restarting $app..."
  cd /var/www/$app
  docker-compose -f docker-compose.server.yml restart
done
```

### Clear All Caches

```bash
#!/bin/bash
for app in app-api app-worker app-web app-admin app-dashboard; do
  CONTAINER="${app}-dev-app"
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Clearing cache for $app..."
    docker exec $CONTAINER php artisan config:clear
    docker exec $CONTAINER php artisan cache:clear
    docker exec $CONTAINER php artisan view:clear
  fi
done
```

### Health Check All Apps

```bash
#!/bin/bash
for port in 8001 8002 8003 8005 8007; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/health.php)
  echo "Port $port: HTTP $STATUS"
done
```

---

## Meta

Open source project. Contributions welcome!

Licensed under MIT. See LICENSE.

---

## References

* [README.md](README.md) - Project overview
* [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Initial setup guide
* [SECURITY.md](SECURITY.md) - Security documentation
