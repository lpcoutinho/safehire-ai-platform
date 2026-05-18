# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.namespace}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = { Name = "${var.namespace}-cluster" }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.namespace}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  tags               = { Name = "${var.namespace}-alb" }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.namespace}-api-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "${var.namespace}-api-tg" }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.namespace}-frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "${var.namespace}-frontend-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# CloudWatch Log Groups for ECS services
locals {
  ecs_service_names = ["api-gateway", "core-management", "agent-worker", "frontend-app"]
}

resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(local.ecs_service_names)
  name              = "/ecs/${var.namespace}/${each.key}"
  retention_in_days = 30
  tags              = { Name = "${var.namespace}-${each.key}-logs" }
}

locals {
  task_definitions = {
    api-gateway = templatefile("${path.module}/../../../../api-gateway/docker/ecs-task-definition.json", {
      REPOSITORY_URL  = "${var.ecr_image_registry}/api-gateway"
      IMAGE_TAG       = var.image_tag
      LOG_GROUP       = "/ecs/${var.namespace}/api-gateway"
      AWS_REGION      = data.aws_region.current.name
      ENVIRONMENT     = var.environment
      RDS_HOST        = var.rds_endpoint
      RDS_PORT        = "5432"
      RDS_DB          = var.db_name
      RDS_USER        = "safehire"
      RDS_PASSWORD    = var.rds_password
      CACHE_HOST      = var.cache_endpoint
      CACHE_PORT      = "6379"
      SQS_QUEUE_URL   = var.sqs_queue_url
      S3_BUCKET       = var.s3_bucket_name
      FRONTEND_URL    = "https://${var.environment}.safehire.ai"
    })
    core-management = templatefile("${path.module}/../../../../core-management-api/docker/ecs-task-definition.json", {
      REPOSITORY_URL  = "${var.ecr_image_registry}/core-management-api"
      IMAGE_TAG       = var.image_tag
      LOG_GROUP       = "/ecs/${var.namespace}/core-management"
      AWS_REGION      = data.aws_region.current.name
      ENVIRONMENT     = var.environment
      RDS_HOST        = var.rds_endpoint
      RDS_PORT        = "5432"
      RDS_DB          = var.db_name
      RDS_USER        = "safehire"
      RDS_PASSWORD    = var.rds_password
      CACHE_HOST      = var.cache_endpoint
      CACHE_PORT      = "6379"
      SQS_QUEUE_URL   = var.sqs_queue_url
      S3_BUCKET       = var.s3_bucket_name
    })
    agent-worker = templatefile("${path.module}/../../../../agent-worker-service/docker/ecs-task-definition.json", {
      REPOSITORY_URL  = "${var.ecr_image_registry}/agent-worker-service"
      IMAGE_TAG       = var.image_tag
      LOG_GROUP       = "/ecs/${var.namespace}/agent-worker"
      AWS_REGION      = data.aws_region.current.name
      ENVIRONMENT     = var.environment
      RDS_HOST        = var.rds_endpoint
      RDS_PORT        = "5432"
      RDS_DB          = var.db_name
      RDS_USER        = "safehire"
      RDS_PASSWORD    = var.rds_password
      CACHE_HOST      = var.cache_endpoint
      CACHE_PORT      = "6379"
      SQS_QUEUE_URL   = var.sqs_queue_url
      S3_BUCKET       = var.s3_bucket_name
    })
    frontend-app = templatefile("${path.module}/../../../../frontend-app/docker/ecs-task-definition.json", {
      REPOSITORY_URL  = "${var.ecr_image_registry}/frontend-app"
      IMAGE_TAG       = var.image_tag
      LOG_GROUP       = "/ecs/${var.namespace}/frontend-app"
      AWS_REGION      = data.aws_region.current.name
      ENVIRONMENT     = var.environment
      API_GATEWAY_URL = "https://${var.environment}.safehire.ai/api"
      AUTH_SECRET     = "changeme-in-production"
    })
  }
}

data "aws_region" "current" {}

resource "aws_ecs_task_definition" "service" {
  for_each = local.task_definitions

  family                   = "${var.namespace}-${each.key}"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  container_definitions    = each.value
  tags = { Name = "${var.namespace}-${each.key}" }
}

locals {
  service_target_groups = {
    api-gateway     = aws_lb_target_group.api.arn
    core-management = aws_lb_target_group.api.arn
    agent-worker    = null
    frontend-app    = aws_lb_target_group.frontend.arn
  }
}

resource "aws_ecs_service" "service" {
  for_each = local.service_target_groups

  name            = "${var.namespace}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.value != null ? [1] : []
    content {
      target_group_arn = each.value
      container_name   = each.key
      container_port   = each.key == "frontend-app" ? 3000 : 8000
    }
  }

  depends_on = [aws_lb_listener.http]
}
