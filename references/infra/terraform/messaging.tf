resource "aws_sns_topic" "orders_events" {
  name = "${var.name_prefix}-orders-events"
}

resource "aws_sqs_queue" "inventory_dlq" {
  name = "${var.name_prefix}-inventory-dlq"
}

resource "aws_sqs_queue" "payments_dlq" {
  name = "${var.name_prefix}-payments-dlq"
}

resource "aws_sqs_queue" "inventory" {
  name = "${var.name_prefix}-inventory-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.inventory_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue" "payments" {
  name = "${var.name_prefix}-payments-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.payments_dlq.arn
    maxReceiveCount     = 5
  })
}

# Allow SNS to publish to SQS
data "aws_iam_policy_document" "inventory_sqs_policy" {
  statement {
    effect = "Allow"
    principals { type = "Service" identifiers = ["sns.amazonaws.com"] }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.inventory.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.orders_events.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "inventory" {
  queue_url = aws_sqs_queue.inventory.id
  policy    = data.aws_iam_policy_document.inventory_sqs_policy.json
}

data "aws_iam_policy_document" "payments_sqs_policy" {
  statement {
    effect = "Allow"
    principals { type = "Service" identifiers = ["sns.amazonaws.com"] }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.payments.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.orders_events.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "payments" {
  queue_url = aws_sqs_queue.payments.id
  policy    = data.aws_iam_policy_document.payments_sqs_policy.json
}

resource "aws_sns_topic_subscription" "inventory" {
  topic_arn = aws_sns_topic.orders_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.inventory.arn
  raw_message_delivery = true
}

resource "aws_sns_topic_subscription" "payments" {
  topic_arn = aws_sns_topic.orders_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.payments.arn
  raw_message_delivery = true
}
