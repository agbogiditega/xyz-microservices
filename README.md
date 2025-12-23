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


