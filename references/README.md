# Reference Artifacts – AWS Full Stacks

This contains:
- Terraform full stack: `infra/terraform`
- CDK (Python) full stack: `infra/cdk`
- Architecture, messaging, and testing reference docs under `docs/`

Choose Terraform OR CDK for provisioning; both implement the same logical stack:
VPC + ECS Fargate + ALB (Orders) + SNS + SQS (+DLQ) + IAM + CloudWatch logs.
