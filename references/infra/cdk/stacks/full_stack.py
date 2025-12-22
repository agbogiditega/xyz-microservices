from aws_cdk import (
    Stack,
    CfnParameter,
    Duration,
    RemovalPolicy,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_ecs_patterns as ecs_patterns,
    aws_iam as iam,
    aws_logs as logs,
    aws_sns as sns,
    aws_sqs as sqs,
    aws_sns_subscriptions as subs,
)
from constructs import Construct

class XyzFullStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, name_prefix: str, **kwargs):
        super().__init__(scope, construct_id, **kwargs)

        # Parameters for image URIs (ECR)
        orders_image = CfnParameter(self, "ordersImage", type="String", default="public.ecr.aws/docker/library/python:3.11-slim")
        inventory_image = CfnParameter(self, "inventoryImage", type="String", default="public.ecr.aws/docker/library/python:3.11-slim")
        payments_image = CfnParameter(self, "paymentsImage", type="String", default="public.ecr.aws/docker/library/python:3.11-slim")

        vpc = ec2.Vpc(
            self,
            "Vpc",
            vpc_name=f"{name_prefix}-vpc",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(name="public", subnet_type=ec2.SubnetType.PUBLIC, cidr_mask=24),
                ec2.SubnetConfiguration(name="private", subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS, cidr_mask=24),
            ],
        )

        cluster = ecs.Cluster(self, "Cluster", vpc=vpc, cluster_name=f"{name_prefix}-cluster")

        topic = sns.Topic(self, "OrdersEventsTopic", topic_name=f"{name_prefix}-orders-events")

        inventory_dlq = sqs.Queue(self, "InventoryDLQ", queue_name=f"{name_prefix}-inventory-dlq", retention_period=Duration.days(14))
        payments_dlq = sqs.Queue(self, "PaymentsDLQ", queue_name=f"{name_prefix}-payments-dlq", retention_period=Duration.days(14))

        inventory_q = sqs.Queue(
            self, "InventoryQueue",
            queue_name=f"{name_prefix}-inventory-queue",
            dead_letter_queue=sqs.DeadLetterQueue(queue=inventory_dlq, max_receive_count=5),
            visibility_timeout=Duration.seconds(60),
        )

        payments_q = sqs.Queue(
            self, "PaymentsQueue",
            queue_name=f"{name_prefix}-payments-queue",
            dead_letter_queue=sqs.DeadLetterQueue(queue=payments_dlq, max_receive_count=5),
            visibility_timeout=Duration.seconds(60),
        )

        topic.add_subscription(subs.SqsSubscription(inventory_q, raw_message_delivery=True))
        topic.add_subscription(subs.SqsSubscription(payments_q, raw_message_delivery=True))

        runtime_role = iam.Role(
            self,
            "TaskRuntimeRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            description="Runtime role for services to publish/consume SNS/SQS",
        )
        runtime_role.add_to_policy(iam.PolicyStatement(
            actions=["sns:Publish"],
            resources=[topic.topic_arn],
        ))
        runtime_role.add_to_policy(iam.PolicyStatement(
            actions=["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
            resources=[inventory_q.queue_arn, payments_q.queue_arn],
        ))

        # CloudWatch Log Groups
        orders_lg = logs.LogGroup(self, "OrdersLogGroup",
                                 log_group_name=f"/ecs/{name_prefix}/orders",
                                 retention=logs.RetentionDays.TWO_WEEKS,
                                 removal_policy=RemovalPolicy.DESTROY)
        inventory_lg = logs.LogGroup(self, "InventoryLogGroup",
                                     log_group_name=f"/ecs/{name_prefix}/inventory",
                                     retention=logs.RetentionDays.TWO_WEEKS,
                                     removal_policy=RemovalPolicy.DESTROY)
        payments_lg = logs.LogGroup(self, "PaymentsLogGroup",
                                    log_group_name=f"/ecs/{name_prefix}/payments",
                                    retention=logs.RetentionDays.TWO_WEEKS,
                                    removal_policy=RemovalPolicy.DESTROY)

        # Orders API behind ALB
        orders_service = ecs_patterns.ApplicationLoadBalancedFargateService(
            self,
            "OrdersService",
            cluster=cluster,
            desired_count=1,
            public_load_balancer=True,
            listener_port=80,
            task_image_options=ecs_patterns.ApplicationLoadBalancedTaskImageOptions(
                image=ecs.ContainerImage.from_registry(orders_image.value_as_string),
                container_port=8010,
                environment={
                    "MESSAGE_BACKEND": "sqs",
                    "SNS_TOPIC_ARN": topic.topic_arn,
                    "AWS_REGION": Stack.of(self).region,
                },
                task_role=runtime_role,
                log_driver=ecs.LogDrivers.aws_logs(stream_prefix="ecs", log_group=orders_lg),
            ),
            memory_limit_mib=1024,
            cpu=512,
        )

        # Internal inventory/payments (no LB)
        inventory_td = ecs.FargateTaskDefinition(self, "InventoryTaskDef", memory_limit_mib=512, cpu=256, task_role=runtime_role)
        inventory_td.add_container(
            "InventoryContainer",
            image=ecs.ContainerImage.from_registry(inventory_image.value_as_string),
            environment={
                "MESSAGE_BACKEND": "sqs",
                "SQS_QUEUE_URL": inventory_q.queue_url,
                "AWS_REGION": Stack.of(self).region,
            },
            logging=ecs.LogDrivers.aws_logs(stream_prefix="ecs", log_group=inventory_lg),
        )
        ecs.FargateService(self, "InventoryService", cluster=cluster, task_definition=inventory_td, desired_count=1)

        payments_td = ecs.FargateTaskDefinition(self, "PaymentsTaskDef", memory_limit_mib=512, cpu=256, task_role=runtime_role)
        payments_td.add_container(
            "PaymentsContainer",
            image=ecs.ContainerImage.from_registry(payments_image.value_as_string),
            environment={
                "MESSAGE_BACKEND": "sqs",
                "SQS_QUEUE_URL": payments_q.queue_url,
                "AWS_REGION": Stack.of(self).region,
            },
            logging=ecs.LogDrivers.aws_logs(stream_prefix="ecs", log_group=payments_lg),
        )
        ecs.FargateService(self, "PaymentsService", cluster=cluster, task_definition=payments_td, desired_count=1)

        # Outputs
        self._alb_dns = orders_service.load_balancer.load_balancer_dns_name
