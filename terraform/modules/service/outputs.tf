output "target_group_arn" {
  value       = aws_lb_target_group.this.arn
  description = "ARN of the target group, for the autoscaling group to attach to."
}

output "instance_role_arn" {
  value       = aws_iam_role.instance.arn
  description = "ARN of the instance role, for attaching further per-resource policies."
}

output "instance_role_name" {
  value       = aws_iam_role.instance.name
  description = "Name of the instance role, for attaching further per-resource policies."
}

output "launch_template_id" {
  value       = aws_launch_template.this.id
  description = "Launch template id, for the autoscaling group."
}

output "launch_template_latest_version" {
  value       = aws_launch_template.this.latest_version
  description = "Latest launch template version, for the autoscaling group."
}
