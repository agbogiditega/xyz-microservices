resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
}

resource "aws_cloudwatch_log_group" "orders" {
  name              = "/ecs/${var.name_prefix}/orders"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "inventory" {
  name              = "/ecs/${var.name_prefix}/inventory"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "payments" {
  name              = "/ecs/${var.name_prefix}/payments"
  retention_in_days = 14
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB ingress"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "service" {
  name        = "${var.name_prefix}-svc-sg"
  description = "Service SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8010
    to_port         = 8010
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "public" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "orders" {
  name        = "${var.name_prefix}-orders-tg"
  port        = 8010
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/docs"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.orders.arn
  }
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    effect = "Allow"
    principals { type = "Service" identifiers = ["ecs-tasks.amazonaws.com"] }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.name_prefix}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_runtime" {
  name               = "${var.name_prefix}-task-runtime"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

data "aws_iam_policy_document" "runtime_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sns_topic.orders_events.arn,
      aws_sqs_queue.inventory.arn,
      aws_sqs_queue.payments.arn
    ]
  }
}

resource "aws_iam_role_policy" "runtime_inline" {
  role   = aws_iam_role.task_runtime.id
  policy = data.aws_iam_policy_document.runtime_policy.json
}

locals {
  orders_image_uri    = var.orders_image != "" ? var.orders_image : "public.ecr.aws/docker/library/python:3.11-slim"
  inventory_image_uri = var.inventory_image != "" ? var.inventory_image : "public.ecr.aws/docker/library/python:3.11-slim"
  payments_image_uri  = var.payments_image != "" ? var.payments_image : "public.ecr.aws/docker/library/python:3.11-slim"
}

resource "aws_ecs_task_definition" "orders" {
  family                   = "${var.name_prefix}-orders"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_runtime.arn

  container_definitions = jsonencode([{
    name  = "orders-service"
    image = local.orders_image_uri
    essential = true
    portMappings = [{ containerPort = 8010 }]
    environment = [
      { name = "MESSAGE_BACKEND", value = "sqs" },
      { name = "AWS_REGION", value = var.region },
      { name = "SNS_TOPIC_ARN", value = aws_sns_topic.orders_events.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.orders.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "orders" {
  name            = "${var.name_prefix}-orders"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orders.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.orders.arn
    container_name   = "orders-service"
    container_port   = 8010
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_task_definition" "inventory" {
  family                   = "${var.name_prefix}-inventory"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_runtime.arn

  container_definitions = jsonencode([{
    name  = "inventory-service"
    image = local.inventory_image_uri
    essential = true
    environment = [
      { name = "MESSAGE_BACKEND", value = "sqs" },
      { name = "AWS_REGION", value = var.region },
      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.inventory.url }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.inventory.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "inventory" {
  name            = "${var.name_prefix}-inventory"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.inventory.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.service.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_task_definition" "payments" {
  family                   = "${var.name_prefix}-payments"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_runtime.arn

  container_definitions = jsonencode([{
    name  = "payments-service"
    image = local.payments_image_uri
    essential = true
    environment = [
      { name = "MESSAGE_BACKEND", value = "sqs" },
      { name = "AWS_REGION", value = var.region },
      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.payments.url }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.payments.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "payments" {
  name            = "${var.name_prefix}-payments"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payments.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.service.id]
    assign_public_ip = false
  }
}
