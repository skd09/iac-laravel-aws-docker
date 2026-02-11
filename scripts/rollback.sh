#!/bin/bash
# =============================================================================
# Rollback Script - Redeploy a previous version
# =============================================================================
# Usage:
#   ./rollback.sh stag app-api              - Show available versions
#   ./rollback.sh stag app-api 2            - Rollback to 2nd most recent
#   ./rollback.sh stag app-api abc123.zip   - Deploy specific zip
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

AWS_REGION="ca-central-1"

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

show_usage() {
    echo "Usage: $0 <environment> <app> [version]"
    echo ""
    echo "Arguments:"
    echo "  environment   - dev or stag"
    echo "  app           - app-api, app-worker, app-web, app-admin, app-dashboard"
    echo "  version       - (optional) version number or zip filename"
    echo ""
    echo "Examples:"
    echo "  $0 stag app-api              # List available versions"
    echo "  $0 stag app-api 2            # Rollback to 2nd most recent"
    echo "  $0 stag app-api abc123.zip   # Deploy specific zip file"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

ENV=$1
APP=$2
VERSION=$3

if [ -z "$ENV" ] || [ -z "$APP" ]; then
    print_error "Missing arguments"
    show_usage
    exit 1
fi

if [[ ! "$ENV" =~ ^(dev|stag)$ ]]; then
    print_error "Invalid environment: $ENV"
    exit 1
fi

if [[ ! "$APP" =~ ^(app-api|app-worker|app-web|app-admin|app-dashboard)$ ]]; then
    print_error "Invalid app: $APP"
    exit 1
fi

S3_BUCKET="myproject-${ENV}-codedeploy-artifacts"
CODEDEPLOY_APP="myproject-${ENV}-apps"
DEPLOYMENT_GROUP="myproject-${ENV}-${APP}"

print_header "Rollback - ${APP} (${ENV})"

# List available versions
echo "Available versions in S3:"
echo ""

VERSIONS=$(aws s3 ls "s3://${S3_BUCKET}/" --region $AWS_REGION | grep "${APP}-" | sort -r | head -20)

if [ -z "$VERSIONS" ]; then
    print_error "No deployments found for ${APP}"
    exit 1
fi

# Display with line numbers
echo "$VERSIONS" | nl -w2 -s'. '
echo ""

# If no version specified, just list and exit
if [ -z "$VERSION" ]; then
    echo "To rollback, run:"
    echo "  $0 $ENV $APP <number>"
    echo ""
    echo "Example: $0 $ENV $APP 2   (deploys 2nd most recent)"
    exit 0
fi

# Determine which zip to deploy
if [[ "$VERSION" =~ \.zip$ ]]; then
    # Full filename provided
    ZIP_FILE="$VERSION"
else
    # Number provided - get nth most recent
    ZIP_FILE=$(echo "$VERSIONS" | sed -n "${VERSION}p" | awk '{print $4}')
fi

if [ -z "$ZIP_FILE" ]; then
    print_error "Could not find version: $VERSION"
    exit 1
fi

echo "Selected: $ZIP_FILE"
echo ""

# Confirm
read -p "Deploy this version? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Cancelled"
    exit 0
fi

# Deploy
print_header "Deploying $ZIP_FILE"

DEPLOYMENT_ID=$(aws deploy create-deployment \
    --application-name "$CODEDEPLOY_APP" \
    --deployment-group-name "$DEPLOYMENT_GROUP" \
    --s3-location bucket=${S3_BUCKET},key=${ZIP_FILE},bundleType=zip \
    --region $AWS_REGION \
    --query 'deploymentId' \
    --output text)

print_success "Deployment started: $DEPLOYMENT_ID"

echo ""
echo "Monitor deployment:"
echo "  aws deploy get-deployment --deployment-id $DEPLOYMENT_ID --region $AWS_REGION --query 'deploymentInfo.status'"
echo ""

# Wait for deployment
echo "Waiting for deployment to complete..."
aws deploy wait deployment-successful --deployment-id "$DEPLOYMENT_ID" --region $AWS_REGION && \
    print_success "Rollback completed successfully!" || \
    print_error "Deployment failed. Check AWS Console for details."
