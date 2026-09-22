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
  description = "Security group id for service instances, from the security module."
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
  description = "Port the service listens on."
}

variable "health_check_path" {
  type        = string
  default     = "/"
  description = "Path the target group polls for health checks."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instance type launched by the launch template."
}

variable "root_volume_size" {
  type        = number
  default     = 8
  description = "Root EBS volume size in GiB."
}
