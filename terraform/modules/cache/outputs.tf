output "endpoint" {
  value       = try(aws_elasticache_replication_group.this[0].primary_endpoint_address, "")
  description = "Cache primary endpoint address, empty when create_cache is false."
}

output "port" {
  value       = try(aws_elasticache_replication_group.this[0].port, "")
  description = "Port the cache listens on, empty when create_cache is false."
}
