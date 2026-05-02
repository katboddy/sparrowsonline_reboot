#!/usr/bin/env bash
# Bootstrap Azure infrastructure for katlauze.dev
#
# Prerequisites:
#   az login
#   az account set --subscription <your-subscription>
#
# Usage: ./infra/bootstrap-azure.sh

set -euo pipefail

# ── Config — edit these ────────────────────────────────────────────────────────
RESOURCE_GROUP="sparrowsonline-rg"
LOCATION="westeurope"
ACR_NAME="sparrowsonlineacr"                  # must be globally unique, lowercase, no hyphens
CONTAINER_APP_ENV="sparrowsonline-env"
CONTAINER_APP_NAME="sparrowsonline-site"
GITHUB_ORG="katboddy"                   # your GitHub username or org
GITHUB_REPO="sparrowwsonline_reboot"
SP_NAME="github-actions-katlauze"
# ──────────────────────────────────────────────────────────────────────────────

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "==> Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "==> Creating Azure Container Registry..."
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Basic \
  --admin-enabled false \
  --output none

ACR_ID=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)

echo "==> Creating Container Apps environment..."
az containerapp env create \
  --name "$CONTAINER_APP_ENV" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --logs-destination none \
  --output none

echo "==> Creating Container App (placeholder image)..."
az containerapp create \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$CONTAINER_APP_ENV" \
  --image "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" \
  --target-port 8000 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 2 \
  --system-assigned \
  --output none

echo "==> Granting Container App managed identity pull access to ACR..."
APP_PRINCIPAL_ID=$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query identity.principalId -o tsv)

az role assignment create \
  --assignee "$APP_PRINCIPAL_ID" \
  --role AcrPull \
  --scope "$ACR_ID" \
  --output none

echo "==> Configuring Container App to use ACR with managed identity..."
az containerapp registry set \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --server "${ACR_NAME}.azurecr.io" \
  --identity system \
  --output none

echo "==> Creating service principal for GitHub Actions..."
SP_JSON=$(az ad sp create-for-rbac --name "$SP_NAME" --skip-assignment --output json)
CLIENT_ID=$(echo "$SP_JSON" | jq -r '.appId')
TENANT_ID=$(echo "$SP_JSON" | jq -r '.tenant')

echo "==> Assigning roles to service principal..."
RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)

# AcrPush — to build and push images
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role AcrPush \
  --scope "$ACR_ID" \
  --output none

# Contributor on the resource group — to update the Container App
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role Contributor \
  --scope "$RG_ID" \
  --output none

echo "==> Setting up OIDC federated credential for GitHub Actions (main branch)..."
az ad app federated-credential create \
  --id "$CLIENT_ID" \
  --parameters "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" \
  --output none

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Done. Add the following to your GitHub repo:"
echo " (Settings → Secrets and variables → Actions)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " SECRETS:"
echo "   AZURE_CLIENT_ID       = $CLIENT_ID"
echo "   AZURE_TENANT_ID       = $TENANT_ID"
echo "   AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo ""
echo " VARIABLES:"
echo "   ACR_NAME              = $ACR_NAME"
echo "   AZURE_RESOURCE_GROUP  = $RESOURCE_GROUP"
echo "   CONTAINER_APP_NAME    = $CONTAINER_APP_NAME"
echo ""
echo " OPTIONAL — set app env vars (MAIL_*, etc.):"
echo "   az containerapp update \\"
echo "     --name $CONTAINER_APP_NAME \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --set-env-vars MAIL_USERNAME=secretref:mail-username \\"
echo "                    MAIL_PASSWORD=secretref:mail-password \\"
echo "                    MAIL_FROM=hello@yourdomain.com \\"
echo "                    MAIL_TO=you@yourdomain.com"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
