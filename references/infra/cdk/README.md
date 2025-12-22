# AWS CDK (Python) – Full Stack

This CDK app provisions:
- VPC (public + private subnets)
- ECS Fargate cluster + services (orders behind ALB; inventory/payments internal)
- SNS topic + SQS queues + DLQs + subscriptions
- IAM roles/policies for publish/consume
- CloudWatch log groups

## Prereqs
- Node.js 18+
- AWS CDK v2
- Python 3.11+

## Bootstrap (once per account/region)
```bash
cd infra/cdk
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cdk bootstrap
```

## Deploy
```bash
cdk deploy XyzFullStack --parameters namePrefix=xyz-dev
```
