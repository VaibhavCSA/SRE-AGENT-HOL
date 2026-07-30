#!/bin/bash
# Simple SRE Agent Lab — deploy script
# No Bicep, no azd, no preview data-plane APIs. Just three GA-status
# Azure CLI commands: containerapp up (builds + deploys from source),
# a standard metric alert, and that's the whole app-side footprint.
set -e

RESOURCE_GROUP="${1:-rg-simple-sre-lab}"
LOCATION="${2:-eastus2}"
APP_NAME="grubify-mini"
ENV_NAME="grubify-mini-env"

echo "==> Creating resource group ${RESOURCE_GROUP}..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "==> Building and deploying ${APP_NAME} from source (this also creates"
echo "    a Container Apps environment and a registry if you don't have one)..."
az containerapp up \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --environment "$ENV_NAME" \
  --source . \
  --target-port 8080 \
  --ingress external

APP_URL=$(az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)
APP_ID=$(az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" \
  --query "id" -o tsv)

echo ""
echo "==> App deployed: https://${APP_URL}"
echo ""

echo "==> Creating the HTTP 5xx metric alert (GA command, not preview)..."
az monitor metrics alert create \
  -n "alert-grubify-mini-5xx" \
  -g "$RESOURCE_GROUP" \
  --scopes "$APP_ID" \
  --condition "total Requests > 3 where StatusCodeCategory includes 5xx" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --severity 3 \
  --description "Alert when grubify-mini returns 5xx errors"

echo ""
echo "=================================================================="
echo " Done. App URL:       https://${APP_URL}"
echo " Container App ID:    ${APP_ID}"
echo " Break it:            curl -X POST https://${APP_URL}/admin/break"
echo " Check it's broken:   curl -i https://${APP_URL}/orders"
echo " Manual fix:          curl -X POST https://${APP_URL}/admin/fix"
echo " Real fix (via agent): restart the container app revision — this"
echo "                       clears the in-memory 'broken' flag for real."
echo "=================================================================="
