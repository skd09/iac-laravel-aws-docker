#!/bin/bash
# =============================================================================
# Validate all Terraform configurations
# =============================================================================

set -e

ENVS=("dev" "stag")

for env in "${ENVS[@]}"; do
    echo "========================================"
    echo "Validating: $env"
    echo "========================================"
    
    cd "terraform/environments/$env"
    
    terraform init -backend=false
    terraform validate
    terraform fmt -check -recursive
    
    cd ../../..
    
    echo "✅ $env validated successfully"
done

echo ""
echo "========================================"
echo "✅ All environments validated!"
echo "========================================"