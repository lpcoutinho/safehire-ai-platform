resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.namespace}-cache-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "valkey" {
  replication_group_id          = "${var.namespace}-valkey"
  description                   = "Valkey cache for SafeHire"
  node_type                     = var.node_type
  num_cache_clusters            = 1
  port                          = 6379
  parameter_group_name          = "default.redis7"
  subnet_group_name             = aws_elasticache_subnet_group.main.name
  security_group_ids            = var.security_group_ids
  automatic_failover_enabled    = false
  multi_az_enabled              = false
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = false

  tags = { Name = "${var.namespace}-valkey" }
}
