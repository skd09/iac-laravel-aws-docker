#!/bin/bash
set -e

LIFECYCLE_EVENT="${LIFECYCLE_EVENT:-unknown}"
DEPLOYMENT_GROUP="${DEPLOYMENT_GROUP_NAME:-unknown}"

APP_NAME=$(echo "$DEPLOYMENT_GROUP" | sed 's/myproject-[^-]*-//')

echo "=== CodeDeploy: $LIFECYCLE_EVENT for $APP_NAME ==="

case "$LIFECYCLE_EVENT" in
    BeforeInstall)
        SCRIPT="/opt/scripts/codedeploy/before_install.sh"
        ;;
    AfterInstall)
        SCRIPT="/opt/scripts/codedeploy/after_install.sh"
        ;;
    ApplicationStart)
        SCRIPT="/opt/scripts/codedeploy/application_start.sh"
        ;;
    ValidateService)
        SCRIPT="/opt/scripts/codedeploy/validate_service.sh"
        ;;
    *)
        echo "Unknown event: $LIFECYCLE_EVENT"
        exit 0
        ;;
esac

if [ -f "$SCRIPT" ]; then
    echo "Running: $SCRIPT $APP_NAME"
    exec "$SCRIPT" "$APP_NAME"
else
    echo "Script not found: $SCRIPT"
    exit 1
fi
