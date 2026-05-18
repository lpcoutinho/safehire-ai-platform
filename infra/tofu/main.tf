module "networking" {
  source = "./modules/networking"

  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  environment         = var.environment
  namespace           = local.namespace
}

module "iam" {
  source = "./modules/iam"

  environment = var.environment
  namespace   = local.namespace
}

module "rds" {
  source = "./modules/rds"

  environment        = var.environment
  namespace          = local.namespace
  vpc_id             = local.vpc_id
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [local.security_group_ids.rds]
  db_password        = var.db_password
  db_instance_class  = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
}

module "storage" {
  source = "./modules/storage"

  environment = var.environment
  namespace   = local.namespace
}

module "messaging" {
  source = "./modules/messaging"

  environment = var.environment
  namespace   = local.namespace
}

module "cache" {
  source = "./modules/cache"

  environment     = var.environment
  namespace       = local.namespace
  vpc_id          = local.vpc_id
  subnet_ids      = local.private_subnet_ids
  security_group_ids = [local.security_group_ids.cache]
  node_type       = var.cache_node_type
}

module "ecs" {
  source = "./modules/ecs"

  environment           = var.environment
  namespace             = local.namespace
  vpc_id                = local.vpc_id
  public_subnet_ids     = local.public_subnet_ids
  private_subnet_ids    = local.private_subnet_ids
  ecs_security_group_id = local.security_group_ids.ecs
  alb_security_group_id = local.security_group_ids.alb
  ecs_execution_role_arn = local.ecs_execution_role_arn
  ecs_task_role_arn      = local.ecs_task_role_arn
  task_cpu              = var.ecs_task_cpu
  task_memory           = var.ecs_task_memory
  desired_count         = var.ecs_desired_count
  image_tag             = var.image_tag
  ecr_image_registry    = var.ecr_image_registry
  rds_endpoint          = module.rds.endpoint
  rds_password          = var.db_password
  cache_endpoint        = module.cache.endpoint
  sqs_queue_url         = module.messaging.queue_url
  sqs_queue_arn         = module.messaging.queue_arn
  s3_bucket_name        = module.storage.bucket_name
  db_name               = module.rds.db_name
}

module "monitoring" {
  source = "./modules/monitoring"

  environment = var.environment
  namespace   = local.namespace
}
