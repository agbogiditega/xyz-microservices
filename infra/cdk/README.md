# CDK Deployment Guide (Exemplar Orders Service)

This guide shows how to deploy the exemplar **Orders** service infrastructure using **AWS CDK (Python)**.

The stack provisions:
- A VPC (2 AZs, minimal default config)
- ECS Cluster + **Fargate** service behind an **Application Load Balancer**
- An **ECR** repository for the Orders container image
- **SNS** topic for order events
- Example downstream **SQS** queue + DLQ subscribed to the SNS topic (represents a consumer like Inventory)
- CloudWatch Logs for the service

> Prerequisites: You need an AWS account with permissions to deploy VPC/ECS/ALB/SNS/SQS/IAM/ECR resources.

---

## 1) Install prerequisites

### Install AWS CLI
Install and verify:
```bash
aws --version


aws configure
Configure AWS credentials

Configure credentials for the target account:

aws configure


Verify you can access the account:

aws sts get-caller-identity

Install Node.js (required for CDK CLI)

Install Node.js 18+ and verify:

node --version
npm --version

Install AWS CDK CLI
npm install -g aws-cdk
cdk --version

Install Python 3.11+ and pip

Verify:

python3 --version
pip3 --version

2) Set up the CDK project

From the repository root:

cd infra/cdk


Create and activate a virtual environment:

python3 -m venv .venv
source .venv/bin/activate


Install dependencies:

pip install -r requirements.txt

3) Set CDK context (account/region)

This project reads account and region from CDK context.

Option A (recommended): set context values when deploying:

cdk deploy -c account=$(aws sts get-caller-identity --query Account --output text) -c region=us-east-1


Option B: set defaults in cdk.json (optional):

{
  "app": "python app.py",
  "context": {
    "account": "123456789012",
    "region": "us-east-1"
  }
}

4) Bootstrap the AWS environment (one-time per account/region)

CDK bootstrapping creates supporting resources CDK needs (like an S3 bucket for assets).

Run:

cdk bootstrap -c account=$(aws sts get-caller-identity --query Account --output text) -c region=us-east-1


If you set context in cdk.json, you can run:

cdk bootstrap

5) Deploy the stack

Preview the changes:

cdk diff -c account=$(aws sts get-caller-identity --query Account --output text) -c region=us-east-1


Deploy:

cdk deploy -c account=$(aws sts get-caller-identity --query Account --output text) -c region=us-east-1


When deployment finishes, CDK will print outputs, including:

AlbDnsName (the public URL for the Orders service)

OrdersEcrRepo (ECR repository URI)

OrderEventsTopicArn

InventoryQueueUrl

6) Build and push the Orders container image to ECR

The infrastructure creates an ECR repo, but you must push an image for ECS to run successfully.

Get the ECR repository URI

From the CDK outputs, copy OrdersEcrRepo.

Or query CloudFormation outputs:

aws cloudformation describe-stacks \
  --stack-name XyzOrdersDev \
  --query "Stacks[0].Outputs"

Authenticate Docker to ECR

Replace REGION and ACCOUNT_ID:

export REGION=us-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecr get-login-password --region $REGION | docker login \
  --username AWS \
  --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

Build the container image

From the repository root (adjust path to your Orders service Dockerfile):

cd ../../
docker build -t orders:latest services/orders_service

Tag and push to ECR

Replace ECR_REPO_URI with the OrdersEcrRepo output:

export ECR_REPO_URI=<paste OrdersEcrRepo here>

docker tag orders:latest ${ECR_REPO_URI}:latest
docker push ${ECR_REPO_URI}:latest

7) Verify the deployment
Check ECS service health

Open AWS Console → ECS → Clusters → ${project}-${env}-cluster (or stack cluster) → Services → Orders service.

Ensure:

Tasks are running

Target group health checks are passing

Call the Orders service

Use the AlbDnsName output:

export ALB_DNS=<paste AlbDnsName here>

curl -s http://${ALB_DNS}/health


Example create order request (based on the Orders OpenAPI):

curl -s -X POST http://${ALB_DNS}/orders \
  -H "Content-Type: application/json" \
  -d '{"sku":"SKU-123","qty":2}'

8) Destroy the stack (cleanup)

To remove all resources created by this stack:

cd infra/cdk
cdk destroy -c account=$(aws sts get-caller-identity --query Account --output text) -c region=us-east-1


Note: ECR repositories may block deletion if they contain images. If destroy fails, delete images in the ECR repo and retry.

Troubleshooting
ECS tasks keep restarting

Common causes:

No image pushed to ECR (push latest and redeploy if needed)

Container port mismatch (ensure the app listens on port 8000 if that’s what infra expects)

Health check endpoint missing (/health must return HTTP 200)

Access denied during deploy

Ensure your AWS identity has permissions for:

CloudFormation, IAM, VPC/EC2, ECS, ELBv2, ECR, SNS, SQS, CloudWatch Logs

CDK bootstrap errors

Make sure you are bootstrapping the same account/region you are deploying to.



