locals {
  environment = var.environment
  namespace   = "safehire-${var.environment}"

  default_tags = {
    Project     = "SafeHire AI"
    Environment = var.environment
    ManagedBy   = "OpenTofu"
    Repository  = "safehire-ai-platform"
  }

  # Shared between modules
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn      = module.iam.ecs_task_role_arn

  security_group_ids = {
    ecs       = module.networking.ecs_security_group_id
    rds       = module.networking.rds_security_group_id
    cache     = module.networking.cache_security_group_id
    alb       = module.networking.alb_security_group_id
  }
}
