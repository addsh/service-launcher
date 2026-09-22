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
  description = "Security group id for the database."
}
