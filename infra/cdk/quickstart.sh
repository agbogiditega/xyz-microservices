#!/usr/bin/env bash
set -euo pipefail

BUILD_IMAGE=false
if [[ "${1:-}" == "--build-image" ]]; then
  BUILD_IMAGE=true
fi

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

echo "Using AWS Account: ${ACCOUNT_ID}"
echo "Using AWS Region : ${REGION}"

command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "ERROR: node not found (install Node.js 18+)"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "ERROR: npm not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }

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

STACK_NAME="XyzOrdersDev"

ECR_REPO_URI=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='OrdersEcrRepo'].OutputValue" \
  --output text \
  --region "${REGION}")

CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='ClusterName'].OutputValue" \
  --output text \
  --region "${REGION}" 2>/dev/null || true)

SERVICE_NAME=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='ServiceName'].OutputValue" \
  --output text \
  --region "${REGION}" 2>/dev/null || true)

echo ""
echo "✅ Deployment complete."
echo "ECR repo: ${ECR_REPO_URI}"

if [[ "$BUILD_IMAGE" == "true" ]]; then
  echo "Building and pushing Orders image to ECR..."

  aws ecr get-login-password --region "${REGION}" | docker login \
    --username AWS \
    --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

  docker build -t orders:latest ../../services/orders_service
  docker tag orders:latest "${ECR_REPO_URI}:latest"
  docker push "${ECR_REPO_URI}:latest"

  echo "Image pushed to ECR."

  # Force ECS to pull the newly pushed image
  if [[ -n "${CLUSTER_NAME}" && -n "${SERVICE_NAME}" && "${CLUSTER_NAME}" != "None" && "${SERVICE_NAME}" != "None" ]]; then
    echo "Forcing ECS new deployment (to pull latest image)..."
    aws ecs update-service \
      --cluster "${CLUSTER_NAME}" \
      --service "${SERVICE_NAME}" \
      --force-new-deployment \
      --region "${REGION}" >/dev/null
    echo "✅ ECS deployment triggered."
  else
    echo "NOTE: Could not determine ECS cluster/service from stack outputs."
    echo "If tasks are still failing, force a new deployment in the ECS console."
  fi
else
  echo "Next: build/push the Orders image to ECR, then force a new ECS deployment."
fi
