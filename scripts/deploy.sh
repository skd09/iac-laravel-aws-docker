#!/bin/bash
# =============================================================================
# Laravel AWS DevOps - Unified Deployment Script
# =============================================================================
# This script deploys and configures EC2 servers for MyProject applications.
#
# USAGE:
#   ./deploy.sh <environment> [options]
#
# ENVIRONMENTS:
#   dev     - Development environment (app-api-dev.example.com, etc.)
#   stag    - Staging environment (app-api-stag.example.com, etc.)
#
# OPTIONS:
#   --setup-only   Only run server setup, don't deploy apps
#   --check        Dry run - show what would change without making changes
#   --verbose      Show detailed output from Ansible
#   --help         Show this help message
#
# EXAMPLES:
#   ./deploy.sh dev                  # Full setup for DEV
#   ./deploy.sh stag                 # Full setup for STAG
#   ./deploy.sh dev --setup-only     # Only server setup
#   ./deploy.sh dev --check          # Dry run
#
# PREREQUISITES:
#   1. Ansible installed locally (brew install ansible)
#   2. AWS CLI configured (for SSM access verification)
#   3. SSH key for EC2 access
#   4. Inventory file configured with EC2 IP
#
# DEPLOYMENT FLOW:
#   This Script → Ansible → EC2 Server
#                           ├── Installs Docker
#                           ├── Configures Apache
#                           ├── Installs CodeDeploy agent
#                           └── Creates deployment scripts
#
#   Then: Bitbucket Push → CodeDeploy → EC2 Scripts → Docker Container
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration
# =============================================================================

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_DIR/ansible"

# =============================================================================
# Functions
# =============================================================================

# Print a styled banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           MYPROJECT DEVOPS - DEPLOYMENT SCRIPT               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print a section header
print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Print status messages
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }

# Show usage information
show_usage() {
    echo "Usage: $0 <environment> [options]"
    echo ""
    echo "Environments:"
    echo "  dev     - Deploy to DEV environment"
    echo "  stag    - Deploy to STAG environment"
    echo ""
    echo "Options:"
    echo "  --setup-only   - Only run server setup (skip app deployment)"
    echo "  --check        - Run in check mode (dry run)"
    echo "  --verbose      - Show verbose output"
    echo "  --help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev                  # Full setup for DEV"
    echo "  $0 stag                 # Full setup for STAG"
    echo "  $0 dev --setup-only     # Only server setup for DEV"
    echo "  $0 stag --check         # Dry run for STAG"
    echo ""
}

# Verify all prerequisites are met before deployment
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # -------------------------------------------------------------------------
    # Check Ansible installation
    # -------------------------------------------------------------------------
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed"
        echo "  Install with: brew install ansible (macOS) or pip install ansible"
        exit 1
    fi
    print_success "Ansible installed: $(ansible --version | head -1)"
    
    # -------------------------------------------------------------------------
    # Check AWS CLI (optional but recommended)
    # -------------------------------------------------------------------------
    if ! command -v aws &> /dev/null; then
        print_warning "AWS CLI not installed (needed for SSM setup)"
    else
        print_success "AWS CLI installed"
    fi
    
    # -------------------------------------------------------------------------
    # Check inventory file exists
    # -------------------------------------------------------------------------
    INVENTORY_FILE="$ANSIBLE_DIR/inventories/${ENV}.ini"
    if [ ! -f "$INVENTORY_FILE" ]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        echo ""
        echo "Please create it from example:"
        echo "  cp $ANSIBLE_DIR/inventories/${ENV}.ini.example $INVENTORY_FILE"
        echo "  # Then update the EC2 IP address"
        exit 1
    fi
    print_success "Inventory file found: $INVENTORY_FILE"
    
    # -------------------------------------------------------------------------
    # Extract SSH key path and EC2 IP from inventory
    # -------------------------------------------------------------------------
    SSH_KEY=$(grep ansible_ssh_private_key_file "$INVENTORY_FILE" | head -1 | sed 's/.*ansible_ssh_private_key_file=\([^ ]*\).*/\1/' | tr -d ' ')
    SSH_KEY="${SSH_KEY/#\~/$HOME}"  # Expand ~ to home directory
    EC2_IP=$(grep ansible_host "$INVENTORY_FILE" | head -1 | sed 's/.*ansible_host=\([^ ]*\).*/\1/')
    
    # Check if EC2 IP is still a placeholder
    if [[ "$EC2_IP" == *"YOUR"* ]] || [[ "$EC2_IP" == *"EC2_IP"* ]]; then
        print_error "EC2 IP not configured in inventory file"
        echo "  Please update ansible_host in: $INVENTORY_FILE"
        exit 1
    fi
    print_success "EC2 IP: $EC2_IP"
    
    # -------------------------------------------------------------------------
    # Check SSH key exists
    # -------------------------------------------------------------------------
    if [ ! -f "$SSH_KEY" ]; then
        print_error "SSH key not found: $SSH_KEY"
        echo "  Please ensure the key exists and has correct permissions (chmod 400)"
        exit 1
    fi
    print_success "SSH key found: $SSH_KEY"
    
    # -------------------------------------------------------------------------
    # Test SSH connectivity to EC2
    # -------------------------------------------------------------------------
    echo ""
    print_info "Testing SSH connectivity to $EC2_IP..."
    if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@$EC2_IP "echo 'SSH OK'" &> /dev/null; then
        print_success "SSH connection successful"
    else
        print_warning "SSH connection failed - server may not be ready"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Run an Ansible playbook
run_ansible() {
    local playbook=$1
    local extra_args=$2
    
    echo ""
    print_info "Running: ansible-playbook -i inventories/${ENV}.ini playbooks/${playbook} $extra_args"
    echo ""
    
    cd "$ANSIBLE_DIR"
    
    if [ "$VERBOSE" = true ]; then
        ansible-playbook -i "inventories/${ENV}.ini" "playbooks/${playbook}" $extra_args -v
    else
        ansible-playbook -i "inventories/${ENV}.ini" "playbooks/${playbook}" $extra_args
    fi
}

# Show completion message with useful information
show_completion() {
    print_header "Deployment Complete!"
    
    echo "Environment:  $(echo $ENV | tr '[:lower:]' '[:upper:]')"
    echo "Server IP:    $EC2_IP"
    echo ""
    echo -e "${CYAN}SSH Access:${NC}"
    echo "  ssh -i $SSH_KEY ubuntu@$EC2_IP"
    echo ""
    echo -e "${CYAN}Apps Configured (Docker Ports):${NC}"
    echo "  ┌─────────────┬───────┬────────────────────────────────────────┐"
    echo "  │ App         │ Port  │ URL                                    │"
    echo "  ├─────────────┼───────┼────────────────────────────────────────┤"
    echo "  │ app-api       │ 8001  │ https://app-api-${ENV}.example.com       │"
    echo "  │ app-worker    │ 8002  │ https://app-worker-${ENV}.example.com    │"
    echo "  │ app-web       │ 8003  │ https://app-web-${ENV}.example.com       │"
    echo "  │ app-admin     │ 8005  │ https://app-admin-${ENV}.example.com     │"
    echo "  │ app-dashboard │ 8007  │ https://app-dashboard-${ENV}.example.com │"
    echo "  └─────────────┴───────┴────────────────────────────────────────┘"
    echo ""
    echo -e "${CYAN}Test Apps Locally:${NC}"
    echo "  curl -s -o /dev/null -w '%{http_code}' http://$EC2_IP:8001/"
    echo "  curl -s -o /dev/null -w '%{http_code}' http://$EC2_IP:8007/"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Ensure RDS security group allows EC2 ($EC2_IP) access"
    echo "  2. Create/verify SSM parameters: ./scripts/setup-ssm.sh ${ENV}"
    echo "  3. Push code to Bitbucket to trigger CodeDeploy"
    echo ""
    print_success "Done!"
}

# =============================================================================
# Main Script
# =============================================================================

# Parse command line arguments
ENV=""
SETUP_ONLY=false
CHECK_MODE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        dev|stag)
            ENV=$1
            shift
            ;;
        --setup-only)
            SETUP_ONLY=true
            shift
            ;;
        --check)
            CHECK_MODE="--check"
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment was specified
if [ -z "$ENV" ]; then
    print_error "Environment not specified"
    show_usage
    exit 1
fi

# Validate environment is valid
if [[ ! "$ENV" =~ ^(dev|stag)$ ]]; then
    print_error "Invalid environment: $ENV (must be 'dev' or 'stag')"
    exit 1
fi

# Display banner and configuration
print_banner

echo "Environment:  $(echo $ENV | tr '[:lower:]' '[:upper:]')"

echo "Project Dir:  $PROJECT_DIR"
echo "Ansible Dir:  $ANSIBLE_DIR"
echo "Mode:         $([ "$SETUP_ONLY" = true ] && echo "Setup Only" || echo "Full Setup")"
[ -n "$CHECK_MODE" ] && echo "Check Mode:   Yes (Dry Run)"
[ "$VERBOSE" = true ] && echo "Verbose:      Yes"

# Run prerequisite checks
check_prerequisites

# Store EC2 IP for completion message
EC2_IP=$(grep ansible_host "$ANSIBLE_DIR/inventories/${ENV}.ini" | head -1 | sed 's/.*ansible_host=\([^ ]*\).*/\1/')
SSH_KEY=$(grep ansible_ssh_private_key_file "$ANSIBLE_DIR/inventories/${ENV}.ini" | head -1 | sed 's/.*ansible_ssh_private_key_file=\([^ ]*\).*/\1/' | tr -d ' ')
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# Run the appropriate playbook
if [ "$SETUP_ONLY" = true ]; then
    print_header "Running Server Setup Only"
    run_ansible "setup-server.yml" "$CHECK_MODE"
else
    print_header "Running Full Setup"
    run_ansible "full-setup.yml" "$CHECK_MODE"
fi

# Show completion message (unless in check mode)
if [ -z "$CHECK_MODE" ]; then
    show_completion
else
    print_header "Check Mode Complete"
    echo "This was a dry run. No changes were made."
    echo "Remove --check to apply changes."
fi
