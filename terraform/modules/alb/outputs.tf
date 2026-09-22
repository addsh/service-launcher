output "public_alb_arn" {
  value       = aws_lb.public.arn
  description = "ARN of the public ALB."
}

output "public_alb_dns_name" {
  value       = aws_lb.public.dns_name
  description = "DNS name of the public ALB."
}

output "public_alb_zone_id" {
  value       = aws_lb.public.zone_id
  description = "Canonical hosted zone id of the public ALB, for Route 53 alias records."
}

output "public_http_listener_arn" {
  value       = aws_lb_listener.public_http.arn
  description = "ARN of the public ALB's HTTP listener."
}

output "public_https_listener_arn" {
  value       = try(aws_lb_listener.public_https[0].arn, null)
  description = "ARN of the public ALB's HTTPS listener, null when certificate_arn is empty."
}

output "internal_alb_arn" {
  value       = aws_lb.internal.arn
  description = "ARN of the internal ALB."
}

output "internal_alb_dns_name" {
  value       = aws_lb.internal.dns_name
  description = "DNS name of the internal ALB."
}

output "internal_alb_zone_id" {
  value       = aws_lb.internal.zone_id
  description = "Canonical hosted zone id of the internal ALB, for Route 53 alias records."
}

output "internal_http_listener_arn" {
  value       = aws_lb_listener.internal_http.arn
  description = "ARN of the internal ALB's HTTP listener."
}

output "internal_https_listener_arn" {
  value       = try(aws_lb_listener.internal_https[0].arn, null)
  description = "ARN of the internal ALB's HTTPS listener, null when certificate_arn is empty."
}
