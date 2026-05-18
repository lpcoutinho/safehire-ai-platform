output "vpc_id" {
  value = module.networking.vpc_id
}

output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "s3_bucket_name" {
  value = module.storage.bucket_name
}

output "sqs_queue_url" {
  value = module.messaging.queue_url
}

output "cache_endpoint" {
  value = module.cache.endpoint
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}
