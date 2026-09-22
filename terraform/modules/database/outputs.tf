output "endpoint" {
  value       = try(aws_db_instance.this[0].address, "")
  description = "Database endpoint address, empty when create_database is false."
}

output "port" {
  value       = try(aws_db_instance.this[0].port, "")
  description = "Port the database listens on, empty when create_database is false."
}

output "secret_arn" {
  value       = try(aws_db_instance.this[0].master_user_secret[0].secret_arn, "")
  description = "Secrets Manager ARN holding the master credentials, empty when create_database is false."
}
