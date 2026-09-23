output "target_group_arn" {
  value       = aws_lb_target_group.this.arn
  description = "ARN of the target group, for CloudWatch alarms and dashboards."
}

output "instance_role_arn" {
  value       = aws_iam_role.instance.arn
  description = "ARN of the instance role, for attaching further per-resource policies."
}

output "instance_role_name" {
  value       = aws_iam_role.instance.name
  description = "Name of the instance role, for attaching further per-resource policies."
}

output "autoscaling_group_name" {
  value       = aws_autoscaling_group.this.name
  description = "Autoscaling group name, for CloudWatch alarms and dashboards."
}
