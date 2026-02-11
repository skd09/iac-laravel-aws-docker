#!/bin/bash
# =============================================================================
# Setup SSM Parameters for .env files
# =============================================================================
# Usage:
#   ./setup-ssm.sh dev              - Setup all apps for DEV
#   ./setup-ssm.sh stag app-dashboard      - Setup only app-dashboard for STAG
#   ./setup-ssm.sh dev --list       - List existing params for DEV
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
AWS_REGION="ca-central-1"
PROJECT_NAME="myproject"
APPS=("app-api" "app-worker" "app-web" "app-admin" "app-dashboard")

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
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }

show_usage() {
    echo "Usage: $0 <environment> [app] [options]"
    echo ""
    echo "Environments:"
    echo "  dev     - DEV environment"
    echo "  stag    - STAG environment"
    echo ""
    echo "Apps (optional - defaults to all):"
    echo "  app-api, app-worker, app-web, app-admin, app-dashboard"
    echo ""
    echo "Options:"
    echo "  --list      - List existing SSM parameters"
    echo "  --delete    - Delete SSM parameter (requires app name)"
    echo "  --help      - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Setup all apps for DEV"
    echo "  $0 dev app-dashboard             # Setup only app-dashboard for DEV"
    echo "  $0 dev --list             # List DEV SSM params"
    echo "  $0 stag app-dashboard --delete   # Delete app-dashboard param for STAG"
    echo ""
}

list_params() {
    local env=$1
    ENV_UPPER=$(echo "$env" | tr '[:lower:]' '[:upper:]')
    print_header "SSM Parameters for $ENV_UPPER"
    
    echo "Path: /${PROJECT_NAME}/${env}/"
    echo ""
    
    aws ssm get-parameters-by-path \
        --path "/${PROJECT_NAME}/${env}/" \
        --recursive \
        --region $AWS_REGION \
        --query 'Parameters[*].[Name,LastModifiedDate]' \
        --output table 2>/dev/null || {
        print_warning "No parameters found or access denied"
    }
}

get_app_url() {
    local env=$1
    local app=$2
    echo "https://${app}-${env}.example.com"
}

get_db_name() {
    local env=$1
    local app=$2
    local db_name="${app//-/_}_${env}"
    echo "$db_name"
}

create_env_template() {
    local env=$1
    local app=$2
    local app_url=$(get_app_url "$env" "$app")
    local db_name=$(get_db_name "$env" "$app")
    
    cat << ENVTEMPLATE
APP_NAME="${app^} ${env^^}"
APP_ENV=${env}
APP_KEY=base64:$(openssl rand -base64 32 2>/dev/null || echo "GENERATE_WITH_php_artisan_key:generate")
APP_DEBUG=$([ "$env" == "dev" ] && echo "true" || echo "false")
APP_URL=${app_url}

LOG_CHANNEL=stack
LOG_LEVEL=$([ "$env" == "dev" ] && echo "debug" || echo "info")

DB_CONNECTION=mysql
DB_HOST=YOUR_RDS_ENDPOINT_HERE
DB_PORT=3306
DB_DATABASE=${db_name}
DB_USERNAME=myproject
DB_PASSWORD=YOUR_DB_PASSWORD_HERE

SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=file
QUEUE_CONNECTION=sync

AWS_DEFAULT_REGION=ca-central-1
AWS_BUCKET=${PROJECT_NAME}-${env}-${app}
ENVTEMPLATE
}

create_param() {
    local env=$1
    local app=$2
    local param_name="/${PROJECT_NAME}/${env}/${app}/.env"
    
    print_header "Creating SSM Parameter: $param_name"
    
    # Check if parameter already exists
    if aws ssm get-parameter --name "$param_name" --region $AWS_REGION &>/dev/null; then
        print_warning "Parameter already exists: $param_name"
        read -p "Do you want to update it? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Create temp file
    TEMP_FILE=$(mktemp)
    create_env_template "$env" "$app" > "$TEMP_FILE"
    
    echo ""
    echo -e "${YELLOW}Please edit the .env file. Update:${NC}"
    echo "  - DB_HOST (RDS endpoint)"
    echo "  - DB_PASSWORD"
    echo "  - Any app-specific settings"
    echo ""
    
    # Open in editor
    if [ -n "$EDITOR" ]; then
        $EDITOR "$TEMP_FILE"
    elif command -v nano &> /dev/null; then
        nano "$TEMP_FILE"
    elif command -v vim &> /dev/null; then
        vim "$TEMP_FILE"
    else
        print_warning "No editor found. Please edit: $TEMP_FILE"
        echo "Press Enter when done..."
        read
    fi
    
    # Show preview (hide passwords)
    echo ""
    echo -e "${CYAN}Preview (passwords hidden):${NC}"
    echo "─────────────────────────────────────────"
    cat "$TEMP_FILE" | sed 's/PASSWORD=.*/PASSWORD=***HIDDEN***/'
    echo "─────────────────────────────────────────"
    echo ""
    
    read -p "Upload to SSM? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ssm put-parameter \
            --name "$param_name" \
            --type "SecureString" \
            --value "$(cat $TEMP_FILE)" \
            --overwrite \
            --region $AWS_REGION
        
        print_success "Parameter created/updated: $param_name"
    else
        print_warning "Cancelled"
    fi
    
    rm -f "$TEMP_FILE"
}

delete_param() {
    local env=$1
    local app=$2
    local param_name="/${PROJECT_NAME}/${env}/${app}/.env"
    
    print_warning "This will delete: $param_name"
    read -p "Are you sure? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ssm delete-parameter --name "$param_name" --region $AWS_REGION && \
            print_success "Deleted: $param_name" || \
            print_error "Failed to delete parameter"
    else
        print_warning "Cancelled"
    fi
}

# =============================================================================
# Main
# =============================================================================

ENV=""
APP=""
LIST_MODE=false
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        dev|stag)
            ENV=$1
            shift
            ;;
        app-api|app-worker|app-web|app-admin|app-dashboard)
            APP=$1
            shift
            ;;
        --list)
            LIST_MODE=true
            shift
            ;;
        --delete)
            DELETE_MODE=true
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

# Validate
if [ -z "$ENV" ]; then
    print_error "Environment not specified"
    show_usage
    exit 1
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# List mode
if [ "$LIST_MODE" = true ]; then
    list_params "$ENV"
    exit 0
fi

# Delete mode
if [ "$DELETE_MODE" = true ]; then
    if [ -z "$APP" ]; then
        print_error "App name required for delete"
        exit 1
    fi
    delete_param "$ENV" "$APP"
    exit 0
fi

# Create mode
ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
print_header "SSM Parameter Setup - $ENV_UPPER"

if [ -n "$APP" ]; then
    # Single app
    create_param "$ENV" "$APP"
else
    # All apps
    echo "Apps to configure: ${APPS[*]}"
    echo ""
    
    for app in "${APPS[@]}"; do
        echo ""
        read -p "Setup $app? (y/n/q to quit) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Qq]$ ]]; then
            break
        elif [[ $REPLY =~ ^[Yy]$ ]]; then
            create_param "$ENV" "$app"
        fi
    done
fi

print_header "Done!"
echo "To verify parameters:"
echo "  $0 $ENV --list"
echo ""
