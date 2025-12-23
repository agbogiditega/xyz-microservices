# XYZ Corporation - AWS Native Distributed Microservices Testing Framework

## Overview
This repository contains an AWS native automated testing framework for a distributed microservices platform developed in python. The platform serves as the backbone for multiple client-facing applications and is designed to run on AWS using managed infrastructure.

The testing framework ensures:
* Reliability through automated validation at every commit
* Scalability by testing service boundaries and async workflows
* Maintainability through standardized test patterns and documentation

It supports unit, integration and end-to-end (E2E) testing across services communicating via REST APIs and message queues and is fully integrated with AWS backed CI/CD pipeline.

## Prerequisites
* Python 3.11+
* Docket Desktop
* AWS CLIv2
* Least privilege IAM permissions for ECS, ECR, CloudWatch Logs, Secrets Manager and CI

## Core Technology Stack

| Layer | Technology |
| -------- | ------- |
| Language | Python 3.11 |
| API Framework | FastAPI |
| Messaging | Amazon SQS/SNS |
| Compute | Amazon ECS (Fargate) |
| CI/CD | GitHub --> AWS |
| Secrets | AWS Secrets Manager |
| Log & Metrics | Amazon CloudWatch |
| Tracing | AWS X-Ray |
| Container Registry | Amazon ECR |

## Local Development Setup
1. Clone the repository
```
git clone https://github.com/xyz-corp/xyz-microservices.git
cd xyz-microservices
```
2. Create and activate virtual environment
```
python -m venv .venv
source .venv/bin/activate     # macOS/Linux
.venv\Scripts\activate        # windows
```
3. Install dependencies
```
pip install --upgrade
pip install -e ".[test]"
```
This installs:
* Runtime dependencies
* Testing dependencies
* Coverage tools

## Running Services Locally
### Start RabbitMQ (Docker)
```
docker run -d \
  --name rabbitmq \
  -p 5672:5672 \
  -p 15672:15672 \
  rabbitmq:3.12-management
```
Management UI: http://localhost:15672  
Default credentials: guest / guest

### Run a service (i.e. Orders Service)
```
cd services/orders_service
python -m uvicorn orders_service.app.main:app --reload --port 8010
```
API docs available at: http://localhost:8010/docs

### Testing Strategy Overview
Detailed  documentation is available in: [Testing Strategy](./docs/testing-strategy.md)

### Test Levels
| Test Type | Purpose | Location |
| -------- | ------- | -------- |
| Unit | Validate business logic | services/**/tests/unit |
| Integration | Validate service and dependencies | services/**/tests/integration | 
| End-to-End | Validate cross service workflows | tests/e2e |

## Running Tests Locally
### Run all tests


