# ECS Execution Role — permite ao ECS baixar imagens e criar logs
data "aws_iam_policy_document" "ecs_execution_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.namespace}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_logs" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# ECS Task Role — permite às tasks acessarem S3, SQS, RDS
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.namespace}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

# Política S3
data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::safehire-curriculos-${var.environment}",
      "arn:aws:s3:::safehire-curriculos-${var.environment}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  name        = "${var.namespace}-s3-access"
  description = "Allow ECS tasks to access S3 buckets"
  policy      = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Política SQS
data "aws_iam_policy_document" "sqs_access" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
    ]
    resources = ["arn:aws:sqs:${data.aws_region.current.name}:*:candidatos-novos-${var.environment}"]
  }
}

data "aws_region" "current" {}

resource "aws_iam_policy" "sqs_access" {
  name        = "${var.namespace}-sqs-access"
  description = "Allow ECS tasks to access SQS queues"
  policy      = data.aws_iam_policy_document.sqs_access.json
}

resource "aws_iam_role_policy_attachment" "sqs_access" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.sqs_access.arn
}

# Política X-Ray
resource "aws_iam_role_policy_attachment" "xray_access" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
