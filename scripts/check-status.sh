#!/bin/bash
# =============================================================================
# Check Status of Deployed Apps
# =============================================================================
# Usage:
#   ./check-status.sh dev     - Check DEV environment
#   ./check-status.sh stag    - Check STAG environment
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_DIR/ansible"

# App configuration
declare -A APP_PORTS=(
    ["app-api"]=8001
    ["app-worker"]=8002
    ["app-web"]=8003
    ["app-admin"]=8005
    ["app-dashboard"]=8007
)

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
    echo "Usage: $0 <environment>"
    echo ""
    echo "Environments:"
    echo "  dev     - Check DEV environment"
    echo "  stag    - Check STAG environment"
    echo ""
}

check_http() {
    local url=$1
    local timeout=${2:-5}
    
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $timeout "$url" 2>/dev/null || echo "000")
    echo "$http_code"
}

# =============================================================================
# Main
# =============================================================================

ENV=$1

if [ -z "$ENV" ]; then
    print_error "Environment not specified"
    show_usage
    exit 1
fi

if [[ ! "$ENV" =~ ^(dev|stag)$ ]]; then
    print_error "Invalid environment: $ENV"
    exit 1
fi

# Get EC2 IP from inventory
INVENTORY_FILE="$ANSIBLE_DIR/inventories/${ENV}.ini"
if [ ! -f "$INVENTORY_FILE" ]; then
    print_error "Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

EC2_IP=$(grep ansible_host "$INVENTORY_FILE" | head -1 | sed 's/.*ansible_host=\([^ ]*\).*/\1/')
SSH_KEY=$(grep ansible_ssh_private_key_file "$INVENTORY_FILE" | head -1 | sed 's/.*ansible_ssh_private_key_file=\([^ ]*\).*/\1/' | tr -d ' ')
SSH_KEY="${SSH_KEY/#\~/$HOME}"

print_header "Status Check - ${ENV^^} Environment"

echo "Server: $EC2_IP"
echo ""

# Check SSH
echo -e "${CYAN}Checking SSH connectivity...${NC}"
if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@$EC2_IP "echo 'OK'" &> /dev/null; then
    print_success "SSH: Connected"
else
    print_error "SSH: Failed"
    exit 1
fi

# Check apps
echo ""
echo -e "${CYAN}Checking Apps...${NC}"
echo ""
echo "┌─────────────┬───────┬─────────────┬──────────────────────────────────────┐"
echo "│ App         │ Port  │ HTTP Status │ URL                                  │"
echo "├─────────────┼───────┼─────────────┼──────────────────────────────────────┤"

for app in app-api app-worker app-web app-admin app-dashboard; do
    port=${APP_PORTS[$app]}
    url="http://${EC2_IP}:${port}/"
    
    http_code=$(check_http "$url")
    
    # Determine status indicator
    if [ "$http_code" == "200" ] || [ "$http_code" == "302" ]; then
        status="${GREEN}${http_code}${NC}        "
    elif [ "$http_code" == "000" ]; then
        status="${RED}DOWN${NC}       "
    else
        status="${YELLOW}${http_code}${NC}        "
    fi
    
    printf "│ %-11s │ %-5s │ %b │ %-36s │\n" "$app" "$port" "$status" "https://${app}-${ENV}.example.com"
done

echo "└─────────────┴───────┴─────────────┴──────────────────────────────────────┘"
echo ""

# Check Docker containers via SSH
echo -e "${CYAN}Checking Docker Containers...${NC}"
echo ""
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$EC2_IP "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E '(NAMES|${ENV})'" 2>/dev/null || print_warning "Could not get container status"

echo ""

# Check disk space
echo -e "${CYAN}Disk Space:${NC}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$EC2_IP "df -h / | tail -1 | awk '{print \"  Used: \" \$3 \" / \" \$2 \" (\" \$5 \")\"}'" 2>/dev/null || true

# Check memory
echo ""
echo -e "${CYAN}Memory:${NC}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$EC2_IP "free -h | grep Mem | awk '{print \"  Used: \" \$3 \" / \" \$2}'" 2>/dev/null || true

echo ""
print_success "Status check complete"
