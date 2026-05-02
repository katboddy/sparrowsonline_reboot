#!/usr/bin/env bash
# Bootstrap AWS infrastructure for katlauze.dev
#
# Prerequisites:
#   aws configure  (or set AWS_PROFILE / AWS_ACCESS_KEY_ID etc.)
#
# Usage: ./infra/bootstrap-aws.sh

set -euo pipefail

# ── Config — edit these ────────────────────────────────────────────────────────
AWS_REGION="eu-west-1"
ECR_REPO="sparrowsonline-site-ecr"
APPRUNNER_SERVICE_NAME="sparrowsonline-site-apprunner"
GITHUB_ORG="katboddy"                   # your GitHub username or org
GITHUB_REPO="sparrowwsonline_reboot"
GITHUB_ACTIONS_ROLE="github-actions-katlauze"
APPRUNNER_ECR_ROLE="apprunner-ecr-katlauze"
# ──────────────────────────────────────────────────────────────────────────────

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_PROVIDER="token.actions.githubusercontent.com"

echo "==> Creating ECR repository..."
aws ecr create-repository \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --output none 2>/dev/null || echo "    ECR repo already exists, skipping."

ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

# ── OIDC provider ─────────────────────────────────────────────────────────────
echo "==> Registering GitHub OIDC provider (if not already present)..."
EXISTING=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?ends_with(Arn, '/${OIDC_PROVIDER}')].Arn" \
  --output text)

if [ -z "$EXISTING" ]; then
  aws iam create-openid-connect-provider \
    --url "https://${OIDC_PROVIDER}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
    --output none
  echo "    Created OIDC provider."
else
  echo "    Already exists, skipping."
fi

OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"

# ── IAM role for GitHub Actions ───────────────────────────────────────────────
echo "==> Creating IAM role for GitHub Actions..."
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF
)

aws iam create-role \
  --role-name "$GITHUB_ACTIONS_ROLE" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --output none 2>/dev/null || echo "    Role already exists, skipping."

echo "==> Attaching policies to GitHub Actions role..."
aws iam attach-role-policy \
  --role-name "$GITHUB_ACTIONS_ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"

aws iam attach-role-policy \
  --role-name "$GITHUB_ACTIONS_ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/AWSAppRunnerFullAccess"

GITHUB_ROLE_ARN=$(aws iam get-role --role-name "$GITHUB_ACTIONS_ROLE" --query Role.Arn --output text)

# ── IAM role for App Runner → ECR ─────────────────────────────────────────────
echo "==> Creating IAM role for App Runner ECR access..."
APPRUNNER_TRUST=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)

aws iam create-role \
  --role-name "$APPRUNNER_ECR_ROLE" \
  --assume-role-policy-document "$APPRUNNER_TRUST" \
  --output none 2>/dev/null || echo "    Role already exists, skipping."

aws iam attach-role-policy \
  --role-name "$APPRUNNER_ECR_ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"

APPRUNNER_ECR_ROLE_ARN=$(aws iam get-role --role-name "$APPRUNNER_ECR_ROLE" --query Role.Arn --output text)

# ── App Runner service ─────────────────────────────────────────────────────────
echo "==> Creating App Runner service..."
SERVICE_JSON=$(aws apprunner create-service \
  --service-name "$APPRUNNER_SERVICE_NAME" \
  --source-configuration "{
    \"ImageRepository\": {
      \"ImageIdentifier\": \"${ECR_URI}:latest\",
      \"ImageRepositoryType\": \"ECR\",
      \"ImageConfiguration\": {\"Port\": \"8000\"}
    },
    \"AuthenticationConfiguration\": {
      \"AccessRoleArn\": \"${APPRUNNER_ECR_ROLE_ARN}\"
    },
    \"AutoDeploymentsEnabled\": false
  }" \
  --instance-configuration "{\"Cpu\": \"0.25 vCPU\", \"Memory\": \"0.5 GB\"}" \
  --region "$AWS_REGION" \
  --output json 2>/dev/null || echo "{}")

SERVICE_ARN=$(echo "$SERVICE_JSON" | jq -r '.Service.ServiceArn // empty')

if [ -z "$SERVICE_ARN" ]; then
  # Service may already exist — fetch ARN
  SERVICE_ARN=$(aws apprunner list-services \
    --region "$AWS_REGION" \
    --query "ServiceSummaryList[?ServiceName=='${APPRUNNER_SERVICE_NAME}'].ServiceArn" \
    --output text)
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Done. Add the following to your GitHub repo:"
echo " (Settings → Secrets and variables → Actions)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " SECRETS:"
echo "   AWS_ROLE_ARN              = $GITHUB_ROLE_ARN"
echo ""
echo " VARIABLES:"
echo "   AWS_REGION                = $AWS_REGION"
echo "   ECR_REPOSITORY            = $ECR_REPO"
echo "   APPRUNNER_SERVICE_ARN     = $SERVICE_ARN"
echo ""
echo " OPTIONAL — set app env vars via the console or:"
echo "   aws apprunner update-service \\"
echo "     --service-arn $SERVICE_ARN \\"
echo "     --source-configuration '{}' \\"
echo "     # Use the App Runner console to set MAIL_* env vars under"
echo "     # Service → Configuration → Configure service → Environment variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
