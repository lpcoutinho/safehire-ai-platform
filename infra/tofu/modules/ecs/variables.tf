variable "environment" {
  type = string
}

variable "namespace" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "image_tag" {
  type = string
}

variable "ecr_image_registry" {
  type = string
}

variable "rds_endpoint" {
  type = string
}

variable "rds_password" {
  type = string
  sensitive = true
}

variable "cache_endpoint" {
  type = string
}

variable "sqs_queue_url" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "db_name" {
  type = string
}
