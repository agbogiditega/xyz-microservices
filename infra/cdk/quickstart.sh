#!/usr/bin/env bash
set -euo pipefail

# Change default region here if needed
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

echo "Using AWS Account: ${ACCOUNT_ID}"
echo "Using AWS Region : ${REGION}"

command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "ERROR: node not found (install Node.js 18+)"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "ERROR: npm not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }

# Install CDK CLI if missing
if ! command -v cdk >/dev/null 2>&1; then
  echo "CDK CLI not found. Installing globally with npm..."
  npm install -g aws-cdk
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "Creating virtualenv..."
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate

echo "Installing Python dependencies..."
pip install --upgrade pip >/dev/null
pip install -r requirements.txt >/dev/null

echo "Bootstrapping CDK (safe to re-run)..."
cdk bootstrap -c account="${ACCOUNT_ID}" -c region="${REGION}"

echo "Deploying stack..."
cdk deploy -c account="${ACCOUNT_ID}" -c region="${REGION}" --require-approval never

echo ""
echo "✅ Deployment complete."
echo "Next: build/push the Orders image to the ECR repo printed in CDK outputs (OrdersEcrRepo)."
