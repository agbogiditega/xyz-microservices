# Terraform – Full Stack (VPC, ECS Fargate, ALB, SNS, SQS, IAM, Logs)

## Prereqs
- Terraform >= 1.6
- AWS credentials configured (e.g., `aws configure` or assumed role)

## Deploy
```bash
cd infra/terraform
terraform init
terraform apply -var="name_prefix=xyz-dev" -var="region=us-east-1"
```

## Destroy
```bash
terraform destroy -var="name_prefix=xyz-dev" -var="region=us-east-1"
```

## Notes
- This stack creates an ALB for `orders-service` and internal ECS services for inventory/payments.
- Images are referenced by ECR repo URLs you provide via variables.
