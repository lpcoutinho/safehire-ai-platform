output "endpoint" {
  value = aws_elasticache_replication_group.valkey.primary_endpoint_address
}

output "port" {
  value = aws_elasticache_replication_group.valkey.port
}
