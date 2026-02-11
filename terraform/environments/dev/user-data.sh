#!/bin/bash
# =============================================================================
# EC2 User Data Script - DEV Environment
# =============================================================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "========================================"
echo "Setting up MyProject Server"
echo "Environment: ${environment}"
echo "========================================"

# Update system
apt-get update
apt-get upgrade -y

# Install basic tools
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    unzip \
    jq \
    awscli \
    mysql-client

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["/"]
      }
    },
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    }
  }
}
CWCONFIG

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create application directory
APP_DIR="/home/ubuntu/myproject-${environment}"
mkdir -p "$APP_DIR"/{apps,docker,logs,scripts}
chown -R ubuntu:ubuntu "$APP_DIR"

# Store infrastructure info
cat > "$APP_DIR/.env.infrastructure" << ENVEOF
ENVIRONMENT=${environment}
PROJECT=${project}
RDS_HOST=${rds_endpoint}
RDS_USERNAME=${rds_username}
RDS_PASSWORD=${rds_password}
REDIS_HOST=${redis_endpoint}
AWS_REGION=${aws_region}
ENVEOF

chown ubuntu:ubuntu "$APP_DIR/.env.infrastructure"
chmod 600 "$APP_DIR/.env.infrastructure"

# System optimizations
cat >> /etc/sysctl.conf << 'SYSEOF'
vm.max_map_count=262144
net.core.somaxconn=65535
fs.file-max=500000
SYSEOF
sysctl -p

# Create swap file (2GB)
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# MOTD Banner
cat > /etc/motd << 'MOTDEOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        Your Organization - DEV Environment             ║
║                                                               ║
║  App Directory: /home/ubuntu/myproject-dev                    ║
║  Config:        .env.infrastructure                           ║
║  Logs:          docker-compose logs -f                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
MOTDEOF

echo "========================================"
echo "User data script complete!"
echo "========================================"