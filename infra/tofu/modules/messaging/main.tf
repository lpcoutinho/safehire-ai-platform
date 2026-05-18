resource "aws_sqs_queue" "candidatos_novos_dlq" {
  name                      = "candidatos-novos-dlq-${var.environment}"
  message_retention_seconds = 1209600

  tags = { Name = "${var.namespace}-candidatos-novos-dlq" }
}

resource "aws_sqs_queue" "candidatos_novos" {
  name                      = "candidatos-novos-${var.environment}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.candidatos_novos_dlq.arn
    maxReceiveCount     = 5
  })

  tags = { Name = "${var.namespace}-candidatos-novos" }
}
