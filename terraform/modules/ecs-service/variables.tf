variable "name" {
  type        = string
  description = "Service name, used to tag and name every resource this module creates."
}

variable "vpc_id" {
  type        = string
  description = "VPC id from the network module, for the target group."
}

variable "instance_security_group_id" {
  type        = string
  description = <<-EOT
    Security group id from the security module, shared with ec2 service
    instances. Fargate awsvpc tasks get their own ENI, not a host, so this is
    not shared with any instance, only with the rule set: ingress from both
    ALBs, egress to the database security group. Same tradeoff the ec2 path
    already makes.
  EOT
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids from the network module. Tasks are never reached directly, only through the ALB, so they get no public IP."
}

variable "exposure" {
  type        = string
  default     = "public"
  description = "Which shared ALB the listener rule attaches to."

  validation {
    condition     = contains(["public", "internal"], var.exposure)
    error_message = "exposure must be either \"public\" or \"internal\"."
  }
}

variable "use_https" {
  type        = bool
  default     = false
  description = <<-EOT
    Attach the listener rule to the HTTPS listener instead of HTTP. Only
    valid when the alb module was built with certificate_arn set; otherwise
    the HTTPS listener ARN passed in is null and this fails to apply.
  EOT
}

variable "public_http_listener_arn" {
  type        = string
  description = "ARN of the public ALB's HTTP listener, from the alb module."
}

variable "public_https_listener_arn" {
  type        = string
  default     = null
  description = "ARN of the public ALB's HTTPS listener, from the alb module. Null when no certificate is configured."
}

variable "internal_http_listener_arn" {
  type        = string
  description = "ARN of the internal ALB's HTTP listener, from the alb module."
}

variable "internal_https_listener_arn" {
  type        = string
  default     = null
  description = "ARN of the internal ALB's HTTPS listener, from the alb module. Null when no certificate is configured."
}

variable "host_header" {
  type        = string
  description = "Host header value that routes traffic to this service."
}

variable "priority" {
  type        = number
  description = <<-EOT
    Listener rule priority. Must be unique per listener; the caller derives
    this deterministically since Terraform has no equivalent of a
    per-listener counter.
  EOT
}

variable "port" {
  type        = number
  default     = 80
  description = "Port the container listens on."
}

variable "health_check_path" {
  type        = string
  default     = "/"
  description = "Path the target group polls for health checks."
}

# public.ecr.aws needs a route to the internet to pull from, same as any
# other public registry. With enable_nat_gateway false (the default) and no
# ECR interface endpoints in modules/network, a task in the private subnets
# cannot pull this image and the service sits at zero running tasks. Either
# turn on enable_nat_gateway or point image at something reachable without
# it.
variable "image" {
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest"
  description = "Container image. Must serve 200 on health_check_path itself; nothing here writes a stub page into the image."
}

variable "cpu" {
  type        = string
  default     = "256"
  description = "Fargate task CPU units. Must be a value ECS accepts for the chosen memory."
}

variable "memory" {
  type        = string
  default     = "512"
  description = "Fargate task memory in MiB. Must be a value ECS accepts for the chosen cpu."
}

variable "min_size" {
  type        = number
  default     = 1
  description = "Minimum, and starting, number of tasks the service runs."
}

variable "max_size" {
  type        = number
  default     = 3
  description = "Maximum number of tasks the service scales to."
}

variable "target_cpu_utilization" {
  type        = number
  default     = 60
  description = "Target average CPU percent the scaling policy holds the service to."
}

variable "public_alb_dns_name" {
  type        = string
  description = "DNS name of the public ALB, from the alb module."
}

variable "public_alb_zone_id" {
  type        = string
  description = "Canonical hosted zone id of the public ALB, from the alb module."
}

variable "internal_alb_dns_name" {
  type        = string
  description = "DNS name of the internal ALB, from the alb module."
}

variable "internal_alb_zone_id" {
  type        = string
  description = "Canonical hosted zone id of the internal ALB, from the alb module."
}

variable "hosted_zone_id" {
  type        = string
  default     = null
  description = "Route 53 hosted zone id to create an alias record for host_header in. Leave null to skip DNS and point it at the ALB some other way."
}
