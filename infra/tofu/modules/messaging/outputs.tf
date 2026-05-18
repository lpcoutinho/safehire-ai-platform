output "queue_url" {
  value = aws_sqs_queue.candidatos_novos.url
}

output "queue_arn" {
  value = aws_sqs_queue.candidatos_novos.arn
}

output "dlq_arn" {
  value = aws_sqs_queue.candidatos_novos_dlq.arn
}
