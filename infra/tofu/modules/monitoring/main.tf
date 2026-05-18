# Log groups for X-Ray
resource "aws_cloudwatch_log_group" "xray" {
  name              = "/ecs/${var.namespace}/xray"
  retention_in_days = 30
  tags = { Name = "${var.namespace}-xray-logs" }
}

# Dashboard de CloudWatch
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.namespace}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", { stat = "Average" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS CPU & Memory"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Sum" }],
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "RDS Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "ALB Requests & Latency"
        }
      },
    ]
  })
}

data "aws_region" "current" {}
