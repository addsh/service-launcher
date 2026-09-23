output "public_alb_security_group_id" {
  value       = aws_security_group.public_alb.id
  description = "Security group id for the public ALB."
}

output "internal_alb_security_group_id" {
  value       = aws_security_group.internal_alb.id
  description = "Security group id for the internal ALB."
}

output "instance_security_group_id" {
  value       = aws_security_group.instance.id
  description = "Security group id for service instances."
}

output "database_security_group_id" {
  value       = aws_security_group.database.id
  description = "Security group id for the shared database."
}

output "service_database_security_group_ids" {
  value       = { for name, sg in aws_security_group.service_database : name => sg.id }
  description = "Security group id for each service's own database, keyed by service name."
}

output "service_cache_security_group_ids" {
  value       = { for name, sg in aws_security_group.service_cache : name => sg.id }
  description = "Security group id for each service's own cache, keyed by service name."
}
