output "target_group_arn" {
  value       = aws_lb_target_group.this.arn
  description = "ARN of the target group, for CloudWatch alarms and dashboards."
}

output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "ECS cluster name, for CloudWatch alarms and dashboards."
}

output "service_name" {
  value       = aws_ecs_service.this.name
  description = "ECS service name, for CloudWatch alarms and dashboards."
}

output "task_role_arn" {
  value       = aws_iam_role.task.arn
  description = "ARN of the task role, for attaching further per-resource policies."
}

output "task_role_name" {
  value       = aws_iam_role.task.name
  description = "Name of the task role, for attaching further per-resource policies."
}
