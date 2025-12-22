output "alb_dns_name" {
  value = aws_lb.public.dns_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.orders_events.arn
}

output "inventory_queue_url" {
  value = aws_sqs_queue.inventory.url
}

output "payments_queue_url" {
  value = aws_sqs_queue.payments.url
}
