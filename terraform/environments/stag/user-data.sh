#!/bin/bash
# =============================================================================
# MyProject STAG - EC2 User Data Script
# =============================================================================

set -e

echo "=========================================="
echo "MyProject STAG Server Bootstrap"
echo "=========================================="

# Update system
apt-get update -y
apt-get upgrade -y

# Install basic packages
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    unzip \
    jq \
    awscli

# Set environment variables
cat >> /etc/environment << 'EOF'
ENVIRONMENT=${environment}
PROJECT=${project}
AWS_REGION=${aws_region}
EOF

# Create marker file
echo "${environment}" > /etc/myproject-environment

echo "=========================================="
echo "Bootstrap complete - ${environment}"
echo "=========================================="